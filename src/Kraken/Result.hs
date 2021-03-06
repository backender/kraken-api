{-# LANGUAGE DeriveGeneric, OverloadedStrings #-}

module Kraken.Result
       (
         Time(..),
         Asset(..),
         Assets(..),
         Balance(..),
         OHLC(..),
         OHLCValue(..),
         Depth(..),
         DepthValue(..),
         DepthElementValue(..),
         Kraken.Result.Result(..)
       ) where

import qualified Data.Map as M
import qualified Data.HashMap.Lazy as HM
import qualified Data.Vector as V
import Control.Monad
import Data.Text
import Data.Aeson
import GHC.Generics

data Time = Time
  { unixtime :: Int
  , rfc1123 :: String
  } deriving (Show, Generic)

instance FromJSON Time

data Asset = Asset
  { altname :: String
  , aclass :: String
  , decimals :: Integer
  , display_decimals :: Integer } deriving (Show, Generic)

instance FromJSON Asset

type Assets = M.Map String Asset

type Balance = M.Map String String

class FromJSON a => Result a

instance Kraken.Result.Result Asset
instance Kraken.Result.Result Time

data OHLCTuple = OHLCTuple Int Double Double Double Double Double Double Int

data OHLCValue = OHLCValue
  { open :: Double
  , high :: Double
  , low :: Double
  , close :: Double
  , vwap :: Double
  , volume :: Double
  , count :: Int
  } deriving Show

data OHLC = OHLC
  { last :: Int
  , values :: M.Map String (M.Map Int OHLCValue) } deriving Show

data DepthElementTuple = DepthElementTuple Double Double Integer

data DepthElementValue = DepthElementValue
  { price :: Double,
    depthVolume :: Double,
    timestamp :: Integer } deriving Show

data DepthValue = DepthValue
  { asks :: [ DepthElementValue ]
  , bids :: [ DepthElementValue ] } deriving (Show, Generic)

newtype Depth = Depth (M.Map String DepthValue) deriving (Show, Generic)

instance FromJSON OHLCTuple where
  parseJSON = withArray "OHLC tuple" $ \a ->
    case V.toList a of
      [t, o, h, l, c, vw, vol, co] -> OHLCTuple <$> parseJSON t <*> parseQuotedDouble o <*> parseQuotedDouble h <*> parseQuotedDouble l <*> parseQuotedDouble c <*> parseQuotedDouble vw <*> parseQuotedDouble vol <*> parseJSON co
      _ -> fail "[Int, 6 String's, Int] expected"
    where
      parseQuotedDouble = parseJSON >=> (return . read)

instance FromJSON OHLC where
  parseJSON = withObject "OHLC result" $ \o ->
    OHLC <$> o .: "last" <*>
    (
      do
        rest <- parseJSON $ Object $ HM.delete "last" o
        return $ (M.map (\a ->
                       Prelude.foldr (\(OHLCTuple t o h l c vw vol co) r ->
                                       M.insert t (OHLCValue o h l c vw vol co) r) M.empty (a::[OHLCTuple]))) rest
    )

instance FromJSON DepthElementTuple where
  parseJSON = withArray "Depth element tuple" $ \a ->
    case V.toList a of
      [p, v, t] -> DepthElementTuple <$> parseQuotedDouble p <*> parseQuotedDouble v <*> parseJSON t
      _ -> fail "[2 String's, Int] expected"
    where
      parseQuotedDouble = parseJSON >=> (return . read)

instance FromJSON DepthElementValue where
  parseJSON o =
    do
      (DepthElementTuple p v t) <- parseJSON o
      return $ DepthElementValue p v t

instance FromJSON DepthValue
instance FromJSON Depth
