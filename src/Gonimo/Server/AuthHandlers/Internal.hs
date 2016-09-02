module Gonimo.Server.AuthHandlers.Internal where

import           Control.Concurrent.STM          (STM, TVar, readTVar)
import           Control.Lens                    ((^.))
import           Control.Monad                   (guard)
import           Control.Monad.Freer             (Eff)
import           Control.Monad.STM.Class         (liftSTM)
import           Control.Monad.Trans.Maybe       (MaybeT (..), runMaybeT)
import qualified Data.Map.Strict                 as M
import           Data.Proxy                      (Proxy (Proxy))
import qualified Data.Set                        as S
import           Gonimo.Database.Effects.Servant (get404)
import           Gonimo.Server.Auth              (AuthServerConstraint,
                                                  authorizeAuthData,
                                                  authorizeJust, clientKey,
                                                  isFamilyMember)
import           Gonimo.Server.DbEntities        (ClientId, Family, FamilyId)
import           Gonimo.Server.Effects           (atomically, getState, timeout)
import           Gonimo.Server.Effects
import           Gonimo.Server.State             (FamilyOnlineState,
                                                  onlineMembers)
import           Gonimo.WebAPI                   (ListDevicesR,
                                                 ListFamiliesR)
import           Servant.API                     ((:>), Capture, Get, JSON)
import           Utils.Control.Monad.Trans.Maybe (maybeT)
import qualified Gonimo.WebAPI.Types              as Client


authorizedPut :: AuthServerConstraint r
              => (TVar FamilyOnlineState -> STM ())
              ->  FamilyId -> ClientId -> ClientId -> Eff r ()
authorizedPut f familyId fromId toId = do
  authorizeAuthData (isFamilyMember familyId)
  authorizeAuthData ((toId ==) . clientKey)

  let fromto = S.fromList [fromId, toId]
  state <- getState
  x <- timeout 2000 $ atomically $ runMaybeT $ do
    a <- (maybeT . (familyId `M.lookup`)) =<< liftSTM (readTVar state)
    b <- liftSTM $ readTVar a
    guard $ fromto `S.isSubsetOf` (M.keysSet $ b^.onlineMembers)
    liftSTM $ f a

  authorizeJust id x


authorizedRecieve :: AuthServerConstraint r
                  => (TVar FamilyOnlineState -> STM (Maybe a))
                  ->  FamilyId -> ClientId -> ClientId -> Eff r a
authorizedRecieve f familyId fromId toId = do
  authorizeAuthData (isFamilyMember familyId)
  authorizeAuthData ((toId ==) . clientKey)

  let fromto = S.fromList [fromId, toId]
  state <- getState
  x <- timeout 2000 $ atomically $ runMaybeT $ do
    a <- (maybeT . (familyId `M.lookup`)) =<< liftSTM (readTVar state)
    b <- liftSTM $ readTVar a
    guard $ fromto `S.isSubsetOf` (M.keysSet $ b^.onlineMembers)
    MaybeT $ f a
  authorizeJust id x

authorizedRecieve' :: AuthServerConstraint r
                  => (TVar FamilyOnlineState -> STM (Maybe a))
                  ->  FamilyId -> ClientId -> Eff r a
authorizedRecieve' f familyId toId = do
  authorizeAuthData (isFamilyMember familyId)
  authorizeAuthData ((toId ==) . clientKey)

  state <- getState
  x <- timeout 2000 $ atomically $ runMaybeT $ do
    a <- (maybeT . (familyId `M.lookup`)) =<< liftSTM (readTVar state)
    MaybeT $ f a
  authorizeJust id x

listDevicesEndpoint  :: Proxy ("onlineStatus" :> ListDevicesR)
listDevicesEndpoint = Proxy
  
listFamiliesEndpoint :: Proxy ("families" :> ListFamiliesR)
listFamiliesEndpoint = Proxy

getDeviceInfosEndpoint :: Proxy ("deviceInfos" :> Capture "familyId" FamilyId :> Get '[JSON] [(ClientId, Client.ClientInfo)])
getDeviceInfosEndpoint = Proxy

-- The following stuff should go somewhere else someday (e.g. to paradise):

-- | Get the family of the requesting device.
--
--   error 404 if not found.
--   TODO: Get this from in memory data structure when available.
getFamily :: ServerConstraint r => FamilyId -> Eff r Family
getFamily fid = runDb $ get404 fid