{-# LANGUAGE FlexibleContexts, ScopedTypeVariables #-}

module Phases.ReprRefnCommon where

import Control.Applicative ( Applicative )
import Control.Monad ( forM_, zipWithM_ )
import Control.Monad.Error ( MonadError, throwError )
import Control.Monad.IO.Class ( MonadIO(..) )
import Control.Monad.State ( MonadState )
import Data.Generics.Uniplate.Direct ( transform )
import Data.List.Split ( splitOn )

import Has
import Language.Essence
import Language.EssenceEvaluator ( runEvaluateExpr )
import Language.EssencePrinters ( prExpr )
import PrintUtils
import UniqueSupply ( nextUniqueInt )
import Utils


type ErrMsg = String
type Domain = Expr
type Structural = Maybe Expr
type ReprName = String
type ReprResult = (ReprName, Domain, Structural)


-- instantiateNames ::
--     ( MonadState st m
--     , MonadIO m
--     , Biplate a Expr
--     , Show a
--     , Has st [Binding]
--     ) => a -> m a
instantiateNames ::
    ( MonadState st m
    , MonadIO m
    , Has st [Binding]
    ) => Expr -> m Expr
instantiateNames x = do
    st <- getM
    
    -- let stInRuleNewVar = [ b | b <- st, fst3 b == InRuleNewVar ]
    let stInRule       = [ b | b <- st, fst3 b == InRule       ]

    let
        forOne (InRule, nm, val) = return . instantiateName nm val
        forOne _ = return

    let
        -- funcs :: [a -> a]
        funcs = map forOne stInRule
    applyAllM x funcs

instantiateNames' ::
    ( MonadState st m
    , MonadIO m
    , Has st [Binding]
    ) => Expr -> m Expr
instantiateNames' x = do
    st <- getM
    let stInRuleNewVar = [ b | b <- st, fst3 b == InRuleNewVar ]
    let stInRule       = [ b | b <- st, fst3 b == InRule       ]

    -- liftIO $ putStrLn "instantiateNames'"
    -- liftIO $ print $ map snd3 stInRuleNewVar
    -- liftIO $ print $ map snd3 stInRule

    let
        forOne (InRule      , nm, val) = return . instantiateName nm val
        forOne (InRuleNewVar, nm, dom) = \ a -> do
            i <- liftIO nextUniqueInt
            let auxName = "AUX_" ++ show i
            let binds   = [(Find, auxName, dom)]
            -- liftIO $ print binds
            -- tell binds
            -- return $ instantiateName nm (Identifier auxName) a
            return $ Bubble (instantiateName nm (Identifier auxName) a) [] binds
        forOne _ = return
    
    let funcs = map forOne stInRule
             ++ map forOne stInRuleNewVar
             ++ map forOne stInRule

    applyAllM x funcs


-- instantiateName :: Biplate a Expr => String -> Expr -> a -> a
instantiateName :: String -> Expr -> Expr -> Expr
instantiateName nm x = transform f
    where
        f (Identifier nm') | nm == nm' = x
        f y = y

introduceLocalBindings :: (MonadState st m, Has st [Binding]) => [Binding] -> m ()
introduceLocalBindings bs = forM_ bs $ \ (bEnum,nm,t) ->
    case bEnum of
        Find    -> addBinding InRuleNewVar nm t
        Letting -> addBinding InRule       nm t
        _       -> addBinding bEnum        nm t


checkWheres ::
    ( Applicative m
    , MonadError ErrMsg m
    , MonadState st m
    , MonadIO m
    , Has st [Binding]
    ) => Where -> m ()
checkWheres (GenericNode HasDomain [Identifier nmP, d]) = do
    let nm = head $ splitOn "#" nmP
    st <- getM
    case [ dom | (bEnum,nm',dom) <- st
               , bEnum `elem` [Find,Given]
               , nm == nm'
               ] of
        [dom] -> checkWheres (GenericNode HasDomain [dom,d])
        _     -> throwError $ "Identifier not found: " ++ nm
checkWheres (GenericNode HasDomain [x,d]) = do
    -- liftIO $ putStrLn $ "trying to match domain " ++ render prExpr x ++ " ~~ " ++ render prExpr d

    -- liftIO $ putStrLn $ "[[checkWheres]]"

    -- st :: [Binding] <- getM
    -- liftIO $ print $ map snd3 st

    matchDomainPattern d x

    -- st :: [Binding] <- getM
    -- liftIO $ print $ map snd3 st
checkWheres x = do
    bindings  <- getM
    (x',logs) <- runEvaluateExpr bindings x
    case x' of
        ValueBoolean True  -> return ()
        ValueBoolean False -> do
            xOut <- maybe (throwError ("cannot render: " ++ show x)) return $ prExpr x
            throwError . renderDoc $ text "where statement evaluated to false:" <+> xOut
        _                  -> do
            xOut <- maybe (throwError ("cannot render: " ++ show x)) return $ prExpr x
            throwError . renderDoc $ text "where statement cannot be fully evaluated:" <+> xOut
                              $+$ vcat (map text logs)

matchDomainPattern ::
    ( MonadError ErrMsg m
    , MonadState st m
    , Has st [Binding]
    ) => Domain -- the pattern
      -> Domain -- domain to match
      -> m ()

matchDomainPattern (Identifier "_") _ = return ()

matchDomainPattern (Identifier nm) dom = addBinding InRule nm dom

matchDomainPattern DomainBoolean
                   DomainBoolean
                   = return ()

matchDomainPattern (DomainIntegerFromTo Nothing Nothing)
                   (DomainIntegerFromTo Nothing Nothing)
                   = return ()
matchDomainPattern (DomainIntegerFromTo Nothing (Just t1))
                   (DomainIntegerFromTo Nothing (Just t2))
                   = matchDomainPattern t1 t2
matchDomainPattern (DomainIntegerFromTo (Just f1) Nothing)
                   (DomainIntegerFromTo (Just f2) Nothing)
                   = matchDomainPattern f1 f2
matchDomainPattern (DomainIntegerFromTo (Just f1) (Just t1))
                   (DomainIntegerFromTo (Just f2) (Just t2))
                   = matchDomainPattern f1 f2 >> matchDomainPattern t1 t2

matchDomainPattern p@(DomainIntegerList xs)
                   v@(DomainIntegerList ys)
                   = if length xs == length ys
                       then zipWithM_ matchDomainPattern xs ys
                       else matchDomainPatternError p v

matchDomainPattern (DomainUnnamed s1 _)
                   (DomainUnnamed s2 _)
                   = matchDomainPattern s1 s2

matchDomainPattern (DomainMatrix i1 e1)
                   (DomainMatrix i2 e2)
                   = matchDomainPattern i1 i2 >> matchDomainPattern e1 e2

matchDomainPattern p@(DomainTuple xs _)
                   v@(DomainTuple ys _)
                   = if length xs == length ys
                       then zipWithM_ matchDomainPattern xs ys
                       else matchDomainPatternError p v

matchDomainPattern (DomainSet s1 mns1 mxs1 dontcare e1 _)
                   (DomainSet s2 mns2 mxs2 _        e2 _)
                   = matchIfJust dontcare s1 s2 >>
                     matchIfJust dontcare mns1 mns2 >>
                     matchIfJust dontcare mxs1 mxs2 >>
                     matchDomainPattern e1 e2

matchDomainPattern (DomainMSet s1 mns1 mxs1 o1 mno1 mxo1 dontcare e1 _)
                   (DomainMSet s2 mns2 mxs2 o2 mno2 mxo2 _        e2 _)
                   = matchIfJust dontcare s1   s2   >>
                     matchIfJust dontcare mns1 mns2 >>
                     matchIfJust dontcare mxs1 mxs2 >>
                     matchIfJust dontcare o1   o2   >>
                     matchIfJust dontcare mno1 mno2 >>
                     matchIfJust dontcare mxo1 mxo2 >>
                     matchDomainPattern e1 e2

matchDomainPattern (DomainFunction fr1 to1 total1 partial1 injective1 bijective1 surjective1 dontcare _)
                   (DomainFunction fr2 to2 total2 partial2 injective2 bijective2 surjective2 _        _)
                   = matchBooleanAttr dontcare total1      total2      >>
                     matchBooleanAttr dontcare partial1    partial2    >>
                     matchBooleanAttr dontcare injective1  injective2  >>
                     matchBooleanAttr dontcare bijective1  bijective2  >>
                     matchBooleanAttr dontcare surjective1 surjective2 >>
                     matchDomainPattern fr1 fr2 >>
                     matchDomainPattern to1 to2

-- TODO: add rest of the domains here!

matchDomainPattern pattern value = matchDomainPatternError pattern value

matchDomainPatternError ::
    ( MonadError ErrMsg m
    , MonadState st m
    , Has st [Binding]
    ) => Domain -> Domain -> m ()
matchDomainPatternError pattern value = do
    pattern' <- maybe (throwError ("cannot render: " ++ show pattern)) return $ prExpr pattern
    value'   <- maybe (throwError ("cannot render: " ++ show value  )) return $ prExpr value
    throwError . renderDoc $ text "matchDomainPattern:" <+> pattern'
                                               <+> text "~~"
                                               <+> value'

matchIfJust ::
    ( MonadError String m
    , MonadState st m
    , Has st [Binding]
    ) => Bool         -- shall I not care?
      -> Maybe Domain -- attr from the pattern
      -> Maybe Domain
      -> m ()
matchIfJust _     Nothing  Nothing   = return ()
matchIfJust _     (Just i) (Just j)  = matchDomainPattern i j
matchIfJust True  Nothing  _         = return ()
matchIfJust False Nothing  (Just {}) = throwError "missing attribute in pattern."
matchIfJust _     (Just {}) _        = throwError "extra attribute in pattern."

matchBooleanAttr ::
    ( MonadError String m
    , MonadState st m
    , Has st [Binding]
    ) => Bool -- shall I not care?
      -> Bool -- attr from the pattern
      -> Bool
      -> m ()
matchBooleanAttr _     False False = return ()
matchBooleanAttr _     True  True  = return ()
matchBooleanAttr True  False _     = return ()
matchBooleanAttr False False True  = throwError "missing attribute in pattern."
matchBooleanAttr _     True  _     = throwError "extra attribute in pattern."


addBinding :: (MonadState st m, Has st [Binding]) => BindingEnum -> String -> Expr -> m ()
addBinding e nm x = modifyM ((e,nm,x) :)
