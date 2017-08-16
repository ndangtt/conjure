{-# LANGUAGE QuasiQuotes #-}

-- | This is an extremely simplified version of type-strengthening
module Conjure.Process.InferAttributes ( inferAttributes ) where

import Conjure.Prelude
import Conjure.Language
import Conjure.Language.Domain.AddAttributes ( mkMin )
import Conjure.Language.Expression.DomainSizeOf
import Conjure.Language.NameResolution ( resolveX, resolveD )


inferAttributes :: (MonadFail m, MonadUserError m, NameGen m) => Model -> m Model
inferAttributes = flip evalStateT [] . go where
    go :: 
        MonadFail m =>
        MonadUserError m =>
        NameGen m =>
        MonadState [(Name, ReferenceTo)] m =>
        Model -> m Model
    go m = do
        forM_ (mStatements m) $ \ st ->
            case st of
                Declaration decl ->
                    case decl of
                        FindOrGiven forg nm dom       -> do
                            dom' <- resolveD dom
                            modify ((nm, DeclNoRepr forg nm dom' NoRegion) :)
                        Letting nm x                  -> do
                            x' <- resolveX x
                            modify ((nm, Alias x') :)
                        LettingDomainDefnUnnamed nm x -> do
                            x' <- resolveX x
                            modify ((nm, Alias (Domain (DomainUnnamed nm x'))) :)
                        LettingDomainDefnEnum _ nms -> do
                            modify ( [ (nm, Alias (Constant (ConstantInt i)))
                                     | (nm, i) <- zip nms [1..]
                                     ] ++)
                        GivenDomainDefnEnum{}       -> return ()             -- ignoring
                _ -> return ()
        transformBiM inferAttributesD m

inferAttributesD ::
    MonadFail m =>
    MonadUserError m =>
    NameGen m =>
    MonadState [(Name, ReferenceTo)] m =>
    Domain () Expression ->
    m (Domain () Expression)
inferAttributesD (DomainPartition () (PartitionAttr partsNum1 partsSize1 isRegular1) innerDomain0) = do
    innerDomain <- resolveD innerDomain0
    -- there cannot be more parts than there are members
    let partsNum2 =
            case domainSizeOf innerDomain of
                Left _err -> partsNum1
                Right n   -> case partsNum1 of
                                SizeAttr_None -> SizeAttr_MaxSize n
                                SizeAttr_Size x -> SizeAttr_Size x
                                SizeAttr_MinSize x -> SizeAttr_MinMaxSize x n
                                SizeAttr_MaxSize x -> SizeAttr_MaxSize (mkMin x n)
                                SizeAttr_MinMaxSize x y -> SizeAttr_MinMaxSize x (mkMin y n)
    -- there cannot be more in a part than there are members
    let partsSize2 =
            case domainSizeOf innerDomain of
                Left _err -> partsNum2
                Right n   -> case partsSize1 of
                                SizeAttr_None -> SizeAttr_MaxSize n
                                SizeAttr_Size x -> SizeAttr_Size x
                                SizeAttr_MinSize x -> SizeAttr_MinMaxSize x n
                                SizeAttr_MaxSize x -> SizeAttr_MaxSize (mkMin x n)
                                SizeAttr_MinMaxSize x y -> SizeAttr_MinMaxSize x (mkMin y n)
    return (DomainPartition () (PartitionAttr partsNum2 partsSize2 isRegular1) innerDomain0)
inferAttributesD (DomainPartitionSequence () (PartitionAttr partsNum1 partsSize1 isRegular1) innerDomain0) = do
    innerDomain <- resolveD innerDomain0
    -- there cannot be more parts than there are members
    let partsNum2 =
            case domainSizeOf innerDomain of
                Left _err -> partsNum1
                Right n   -> case partsNum1 of
                                SizeAttr_None -> SizeAttr_MaxSize n
                                SizeAttr_Size x -> SizeAttr_Size x
                                SizeAttr_MinSize x -> SizeAttr_MinMaxSize x n
                                SizeAttr_MaxSize x -> SizeAttr_MaxSize (mkMin x n)
                                SizeAttr_MinMaxSize x y -> SizeAttr_MinMaxSize x (mkMin y n)
    -- there cannot be more in a part than there are members
    let partsSize2 =
            case domainSizeOf innerDomain of
                Left _err -> partsNum2
                Right n   -> case partsSize1 of
                                SizeAttr_None -> SizeAttr_MaxSize n
                                SizeAttr_Size x -> SizeAttr_Size x
                                SizeAttr_MinSize x -> SizeAttr_MinMaxSize x n
                                SizeAttr_MaxSize x -> SizeAttr_MaxSize (mkMin x n)
                                SizeAttr_MinMaxSize x y -> SizeAttr_MinMaxSize x (mkMin y n)
    return (DomainPartitionSequence () (PartitionAttr partsNum2 partsSize2 isRegular1) innerDomain0)
inferAttributesD d = return d

