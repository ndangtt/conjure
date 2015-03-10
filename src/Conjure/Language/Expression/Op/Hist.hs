{-# LANGUAGE DeriveGeneric, DeriveDataTypeable, DeriveFunctor, DeriveTraversable, DeriveFoldable #-}

module Conjure.Language.Expression.Op.Hist where

import Conjure.Prelude
import Conjure.Language.Expression.Op.Internal.Common


data OpHist x = OpHist x
    deriving (Eq, Ord, Show, Data, Functor, Traversable, Foldable, Typeable, Generic)

instance Serialize x => Serialize (OpHist x)
instance Hashable  x => Hashable  (OpHist x)
instance ToJSON    x => ToJSON    (OpHist x) where toJSON = genericToJSON jsonOptions
instance FromJSON  x => FromJSON  (OpHist x) where parseJSON = genericParseJSON jsonOptions

instance (TypeOf x, Pretty x) => TypeOf (OpHist x) where
    typeOf p@(OpHist a) = do
        tyA <- typeOf a
        case tyA of
            TypeMSet     aInner -> return $ TypeMatrix TypeInt $ TypeTuple [aInner, TypeInt]
            TypeMatrix _ aInner -> return $ TypeMatrix TypeInt $ TypeTuple [aInner, TypeInt]
            TypeList     aInner -> return $ TypeMatrix TypeInt $ TypeTuple [aInner, TypeInt]
            _ -> raiseTypeError p

instance Pretty x => DomainOf (OpHist x) x where
    domainOf op = na $ "evaluateOp{OpHist}:" <++> pretty op

instance EvaluateOp OpHist where
    evaluateOp (OpHist (ConstantAbstract (AbsLitMSet cs))) = return $ ConstantAbstract $ AbsLitMatrix
        (DomainInt [RangeBounded 1 (fromInt $ genericLength $ histogram cs)])
        [ ConstantAbstract $ AbsLitTuple [e, ConstantInt n] | (e, n) <- histogram cs ]
    evaluateOp (OpHist (ConstantAbstract (AbsLitMatrix _ cs))) = return $ ConstantAbstract $ AbsLitMatrix
        (DomainInt [RangeBounded 1 (fromInt $ genericLength $ histogram cs)])
        [ ConstantAbstract $ AbsLitTuple [e, ConstantInt n] | (e, n) <- histogram cs ]
    evaluateOp op = na $ "evaluateOp{OpHist}:" <++> pretty (show op)

instance SimplifyOp OpHist x where
    simplifyOp _ = na "simplifyOp{OpHist}"

instance Pretty x => Pretty (OpHist x) where
    prettyPrec _ (OpHist a) = "hist" <> prParens (pretty a)