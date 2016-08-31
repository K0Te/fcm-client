{-# LANGUAGE DeriveDataTypeable         #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE TemplateHaskell            #-}


-- | Google Firebase Cloud Messaging model / JSON conversions.
--   https://firebase.google.com/docs/cloud-messaging/http-server-ref
--
--   This module re-exports JSON types with a few convenience wrappers
--   around selected fields.
--
module FCMClient.Types (
  J.FCMData
, FCMPriority(..)
, FCMLocValue(..)
, J.FCMNotification
, J.newFCMNotification
, J.fcmTitle
, J.fcmBody
, J.fcmIcon
, J.fcmSound
, J.fcmTag
, J.fcmColor
, J.fcmBadge
, J.fcmClickAction
, J.fcmBodyLocKey
, fcmBodyLocArgs
, J.fcmTitleLocKey
, fcmTitleLocArgs
, J.FCMMessage
, J.newFCMMessage
, J.fcmTo
, J.fcmRegistrationIDs
, J.fcmCondition
, J.fcmCollapseKey
, fcmPriority
, fcmContentAvailable
, fcmDelayWhileIdle
, J.fcmTimeToLive
, J.fcmRestrictedPackageName
, fcmDryRun
, J.fcmData
, J.fcmNotification
, fcmWithNotification
) where


import           Control.Lens
import           Data.Aeson
import           Data.Aeson.Types as J
import           Data.List.NonEmpty (nonEmpty)
import           Data.Maybe
import           Data.Scientific (Scientific)
import           Data.String
import           Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Lazy as LT
import qualified Data.Text.Lazy.Encoding as TE
import qualified FCMClient.JSON.Types as J




data FCMPriority = FCMPriorityNormal
                 | FCMPriorityHigh
                 deriving (Eq, Show, Ord)

-- A subset of JSON values suitable for string localization format
data FCMLocValue = FCMLocString !Text
                 | FCMLocNumber !Scientific
                 | FCMLocBool !Bool
                 deriving (Eq, Read, Show, Ord)

instance ToJSON FCMLocValue where
  toJSON (FCMLocString x) = toJSON x
  toJSON (FCMLocNumber x) = toJSON x
  toJSON (FCMLocBool x)   = toJSON x

  toEncoding (FCMLocString x) = toEncoding x
  toEncoding (FCMLocNumber x) = toEncoding x
  toEncoding (FCMLocBool x)   = toEncoding x

instance FromJSON FCMLocValue where
  parseJSON (J.String x) = return $ FCMLocString x
  parseJSON (J.Number x) = return $ FCMLocNumber x
  parseJSON (J.Bool x)   = return $ FCMLocBool x
  parseJSON _            = fail "FCMLocValue"


-- | Shortcut for string localized parameters
instance IsString FCMLocValue where
  fromString = FCMLocString . T.pack


-- | Utility function, Aeson-convert to Text (some JSON string fields are expected to contain JSON).
aesonTxtPr :: (Applicative f, Choice p, ToJSON a1, FromJSON a)
           => p [a] (f [a1])
           -> p (Maybe Text) (f (Maybe Text))
aesonTxtPr =
  (prism' (fmap (LT.toStrict . TE.decodeUtf8)) (Just . (fmap (TE.encodeUtf8 . LT.fromStrict)))) .
    (prism' (fmap (encode) . nonEmpty)  (Just . fromMaybe [] . decode . fromMaybe ""))


-- | Typed lens focused on localized notification body arguments.
fcmBodyLocArgs :: (Applicative f, Functor f)
               => ([FCMLocValue] -> f [FCMLocValue])
               -> J.FCMNotification -> f J.FCMNotification
fcmBodyLocArgs = J.fcmBodyLocArgs . aesonTxtPr



-- | Typed lens focused on localized notification title arguments.
fcmTitleLocArgs :: (Applicative f, Functor f)
                => ([FCMLocValue] -> f [FCMLocValue])
                -> J.FCMNotification -> f J.FCMNotification
fcmTitleLocArgs = J.fcmTitleLocArgs . aesonTxtPr



-- | Typed lens focused on message priority.
fcmPriority :: (Applicative f, Functor f)
            => (FCMPriority -> f FCMPriority)
            -> J.FCMMessage -> f J.FCMMessage
fcmPriority = J.fcmPriority . (prism' fcmPriorityToText (Just .textToFcmPriority))
  where fcmPriorityToText FCMPriorityNormal = Nothing
        fcmPriorityToText FCMPriorityHigh   = Just "high"
        textToFcmPriority (Just "high")     = FCMPriorityHigh
        textToFcmPriority _                 = FCMPriorityNormal



maybeBoolPr :: (Applicative f, Functor f)
            => (Bool -> f Bool)
            -> (Maybe Bool) -> f (Maybe Bool)
maybeBoolPr = prism' (\x -> if x then Just x else Nothing) (Just . fromMaybe False)


-- | Sets content available field when True, sets Nothing when False.
fcmContentAvailable :: (Applicative f, Functor f)
                    => (Bool -> f Bool)
                    -> J.FCMMessage -> f J.FCMMessage
fcmContentAvailable = J.fcmContentAvailable . maybeBoolPr


-- | Sets delay while idle field when True, sets Nothing when False.
fcmDelayWhileIdle :: (Applicative f, Functor f)
                  => (Bool -> f Bool)
                  -> J.FCMMessage -> f J.FCMMessage
fcmDelayWhileIdle = J.fcmDelayWhileIdle . maybeBoolPr


-- | Sets dry run field when True, sets Nothing when False.
fcmDryRun :: (Applicative f, Functor f)
          => (Bool -> f Bool)
          -> J.FCMMessage -> f J.FCMMessage
fcmDryRun = J.fcmDryRun . maybeBoolPr


-- | Creates default empty notification if missing
fcmWithNotification :: (Applicative f, Functor f)
                    => (J.FCMNotification -> f J.FCMNotification)
                    -> J.FCMMessage -> f J.FCMMessage
fcmWithNotification = J.fcmNotification . justNotif
  where justNotif f maybeN = case maybeN
                               of Nothing -> fmap Just (f J.newFCMNotification)
                                  Just n  -> fmap Just (f n)