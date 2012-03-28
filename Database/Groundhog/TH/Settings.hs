{-# LANGUAGE TemplateHaskell, FlexibleInstances, OverloadedStrings, RecordWildCards #-}

module Database.Groundhog.TH.Settings
  ( PersistSettings(..)
  , PSEntityDef(..)
  , PSEmbeddedDef(..)
  , PSConstructorDef(..)
  , PSFieldDef(..)
  , PSEmbeddedFieldDef(..)
  ) where

import Database.Groundhog.Core(Constraint(..))
import Language.Haskell.TH.Syntax(Lift(..))
import Control.Applicative
import Control.Monad(mzero)
import Data.Yaml
  
data PersistSettings = PersistSettings {definitions :: [Either PSEntityDef PSEmbeddedDef]} deriving Show

data PSEntityDef = PSEntityDef {
    psDataName :: String -- SomeData
  , psDbEntityName :: Maybe String  -- SQLSomeData
  , psConstructors :: Maybe [PSConstructorDef]
} deriving Show

data PSEmbeddedDef = PSEmbeddedDef {
    psEmbeddedName :: String
  , psDbEmbeddedName :: Maybe String -- used only to set polymorphic part of name of its container
  , psEmbeddedFields :: Maybe [PSFieldDef]
} deriving Show

data PSConstructorDef = PSConstructorDef {
    psConstrName    :: String -- U2
  , psPhantomConstrName :: Maybe String -- U2Constructor
  , psDbConstrName    :: Maybe String -- SQLU2
  , psConstrParams  :: Maybe [PSFieldDef]
  , psConstrConstrs :: Maybe [Constraint]
} deriving Show

data PSFieldDef = PSFieldDef {
    psFieldName :: String -- bar
  , psDbFieldName :: Maybe String -- SQLbar
  , psExprName :: Maybe String -- BarField
  , psEmbeddedDef :: Maybe [PSEmbeddedFieldDef]
} deriving Show

data PSEmbeddedFieldDef = PSEmbeddedFieldDef {
    psEmbeddedFieldName :: String -- bar
  , psDbEmbeddedFieldName :: Maybe String -- SQLbar
  , psSubEmbedded :: Maybe [PSEmbeddedFieldDef]
} deriving Show

instance Lift PersistSettings where
  lift (PersistSettings {..}) = [| PersistSettings $(lift definitions) |]

instance Lift PSEntityDef where
  lift (PSEntityDef {..}) = [| PSEntityDef $(lift psDataName) $(lift psDbEntityName) $(lift psConstructors) |]

instance Lift PSEmbeddedDef where
  lift (PSEmbeddedDef {..}) = [| PSEmbeddedDef $(lift psEmbeddedName) $(lift psDbEmbeddedName) $(lift psEmbeddedFields) |]

instance Lift PSConstructorDef where
  lift (PSConstructorDef {..}) = [| PSConstructorDef $(lift psConstrName) $(lift psPhantomConstrName) $(lift psDbConstrName) $(lift psConstrParams) $(lift psConstrConstrs) |]

instance Lift Constraint where
  lift (Constraint name fields) = [| Constraint $(lift name) $(lift fields) |]

instance Lift PSFieldDef where
  lift (PSFieldDef {..}) = [| PSFieldDef $(lift psFieldName) $(lift psDbFieldName) $(lift psExprName) $(lift psEmbeddedDef) |]

instance Lift PSEmbeddedFieldDef where
  lift (PSEmbeddedFieldDef {..}) = [| PSEmbeddedFieldDef $(lift psEmbeddedFieldName) $(lift psDbEmbeddedFieldName) $(lift psSubEmbedded) |]

instance FromJSON PersistSettings where
  {- it allows omitting parts of the settings file. All these forms are possible:
        definitions:
          - entity:name
        ---
          - entity:name
        ---
          entity: name
  -}
  parseJSON value = PersistSettings <$> case value of
    Object v -> do
      defs <- v .:? "definitions"
      case defs of
        Just defs'@(Array _) -> parseJSON defs'
        Just _ -> mzero
        Nothing -> fmap (\a -> [a]) $ parseJSON value
    defs@(Array _) -> parseJSON defs
    _ -> mzero

instance FromJSON (Either PSEntityDef PSEmbeddedDef) where
  parseJSON (Object v) = do
    entity   <- v .:? "entity"
    embedded <- v .:? "embedded"
    case (entity, embedded) of
      (Just _, Nothing) -> fmap Left $ PSEntityDef <$> v .: "entity" <*> v .:? "dbName" <*> v .:? "constructors"
      (Nothing, Just _) -> fmap Right $ PSEmbeddedDef <$> v .: "embedded" <*> v .:? "dbName" <*> v .:? "fields"
      (Just entName, Just embName) -> fail $ "Record has both entity name " ++ entName ++ " and embedded name " ++ embName
      (Nothing, Nothing) -> fail "Record must have either entity name or embedded name"
  parseJSON _          = mzero

instance FromJSON PSConstructorDef where
  parseJSON (Object v) = PSConstructorDef <$> v .: "name" <*> v .:? "phantomName" <*> v .:? "dbName" <*> v .:? "constrParams" <*> v .:? "constraints"
  parseJSON _          = mzero

instance FromJSON Constraint where
  parseJSON (Object v) = Constraint <$> v .: "name" <*> v .: "fields"
  parseJSON _          = mzero

instance FromJSON PSFieldDef where
  parseJSON (Object v) = PSFieldDef <$> v .: "name" <*> v .:? "dbName" <*> v .:? "exprName" <*> v .:? "embeddedType"
  parseJSON _          = mzero

instance FromJSON PSEmbeddedFieldDef where
  parseJSON (Object v) = PSEmbeddedFieldDef <$> v .: "name" <*> v .:? "dbName" <*> v .:? "embeddedType"
  parseJSON _          = mzero