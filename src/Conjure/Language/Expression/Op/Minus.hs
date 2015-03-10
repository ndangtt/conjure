{-# LANGUAGE DeriveGeneric, DeriveDataTypeable, DeriveFunctor, DeriveTraversable, DeriveFoldable #-}

module Conjure.Language.Expression.Op.Minus where

import Conjure.Prelude
import Conjure.Language.Expression.Op.Internal.Common


data OpMinus x = OpMinus x x
    deriving (Eq, Ord, Show, Data, Functor, Traversable, Foldable, Typeable, Generic)

instance Serialize x => Serialize (OpMinus x)
instance Hashable  x => Hashable  (OpMinus x)
instance ToJSON    x => ToJSON    (OpMinus x) where toJSON = genericToJSON jsonOptions
instance FromJSON  x => FromJSON  (OpMinus x) where parseJSON = genericParseJSON jsonOptions

instance BinaryOperator (OpMinus x) where
    opLexeme _ = L_Minus

instance (TypeOf x, Pretty x) => TypeOf (OpMinus x) where
    typeOf p@(OpMinus a b) = do
        tya <- typeOf a
        case tya of
            TypeInt{}       -> return ()
            TypeSet{}       -> return ()
            TypeMSet{}      -> return ()
            TypeFunction{}  -> return ()
            TypeRelation{}  -> return ()
            TypePartition{} -> return ()
            _               -> raiseTypeError p
        tyb <- typeOf b
        if typesUnify [tya, tyb]
            then return $ mostDefined [tya,tyb]
            else raiseTypeError p

instance Pretty x => DomainOf (OpMinus x) x where
    domainOf op = na $ "evaluateOp{OpMinus}:" <++> pretty op

instance EvaluateOp OpMinus where
    evaluateOp (OpMinus (ConstantInt a) (ConstantInt b)) = return $ ConstantInt (a - b)
    evaluateOp p@(OpMinus (ConstantAbstract (AbsLitSet as)) (ConstantAbstract (AbsLitSet bs))) = do
        ty <- typeOf p
        let outs =
                [ a
                | a <- as
                , a `notElem` bs
                ]
        return $ if null outs
            then TypedConstant (ConstantAbstract (AbsLitSet [])) ty
            else ConstantAbstract $ AbsLitSet outs
    evaluateOp p@(OpMinus (ConstantAbstract (AbsLitMSet as)) (ConstantAbstract (AbsLitMSet bs))) = do
        ty <- typeOf p
        let asHist = histogram as
            bsHist = histogram bs
            allElems = sortNub (as++bs)
            outs =
                [ replicate (fromInteger (countA - countB)) e
                | e <- allElems
                , let countA = fromMaybe 0 (e `lookup` asHist)
                , let countB = fromMaybe 0 (e `lookup` bsHist)
                ]                
        return $ if null outs
            then TypedConstant (ConstantAbstract (AbsLitMSet [])) ty
            else ConstantAbstract $ AbsLitMSet $ concat outs
    evaluateOp p@(OpMinus (ConstantAbstract (AbsLitFunction as)) (ConstantAbstract (AbsLitFunction bs))) = do
        ty <- typeOf p
        let outs =
                [ a
                | a <- as
                , a `notElem` bs
                ]
        return $ if null outs
            then TypedConstant (ConstantAbstract (AbsLitFunction [])) ty
            else ConstantAbstract (AbsLitFunction outs)
    evaluateOp op = na $ "evaluateOp{OpMinus}:" <++> pretty (show op)

instance SimplifyOp OpMinus x where
    simplifyOp _ = na "simplifyOp{OpMinus}"

instance Pretty x => Pretty (OpMinus x) where
    prettyPrec prec op@(OpMinus a b) = prettyPrecBinOp prec [op] a b