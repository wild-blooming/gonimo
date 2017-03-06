{-# LANGUAGE RecursiveDo #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Gonimo.Client.ConfirmationButton where

import Reflex.Dom.Core
import Data.Map (Map)
import Data.Text (Text)
import Control.Monad.Fix (MonadFix)
import Gonimo.Client.Reflex.Dom
import Data.Monoid

type ConfirmationConstraint t m= (PostBuild t m, DomBuilder t m, MonadFix m, MonadHold t m)

data Confirmed = No | Yes

confirmationButton :: forall t m. ConfirmationConstraint t m
                      => Map Text Text -> m () -> m () -> m (Event t ())
confirmationButton attrs inner = confirmationEl (buttonAttr attrs inner)

confirmationEl :: forall t m. ConfirmationConstraint t m
                      => m (Event t ()) -> m () -> m (Event t ())
confirmationEl someButton confirmationText = mdo
  clicked <- someButton
  confirmationDialog <- holdDyn (pure never) $ leftmost [ const (confirmationBox confirmationText) <$> clicked
                                                        , const (pure never) <$> gotAnswer
                                                        ]
  gotAnswer <- switchPromptly never =<< dyn confirmationDialog
  pure $ push (\answer -> case answer of
                            No -> pure Nothing
                            Yes -> pure $ Just ()
              ) gotAnswer


confirmationBox :: forall t m. ConfirmationConstraint t m => m () -> m (Event t Confirmed)
confirmationBox confirmationText = do
  elClass "div" "hCenteredOverlay fullScreen" $ do
    elClass "div" "vCenteredBox" $ do
      elClass "div" "panel panel-default" $ do
        elClass "div" "panel-heading" $ elClass "h3" "panel-title" $ text "Are you sure?"
        elClass "div" "panel-body" $ do
          confirmationText
          el "div" $ do
            yesClicked <- buttonAttr ("class" =: "btn btn-success" <> "role" =: "button" <> "type" =: "button") $ text "Yes"
            noClicked <- buttonAttr ("class" =: "btn btn-danger" <> "role" =: "button" <> "type" =: "button") $ text "No"
            pure $ leftmost [ const No <$> noClicked, const Yes <$> yesClicked ]

