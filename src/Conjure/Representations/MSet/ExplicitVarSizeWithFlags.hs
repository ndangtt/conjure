{-# LANGUAGE QuasiQuotes #-}

module Conjure.Representations.MSet.ExplicitVarSizeWithFlags ( msetExplicitVarSizeWithFlags ) where

-- conjure
import Conjure.Prelude
import Conjure.Language
import Conjure.Language.DomainSizeOf
import Conjure.Language.Expression.DomainSizeOf ()
import Conjure.Language.ZeroVal ( zeroVal, EnumerateDomain )
import Conjure.Representations.Internal
import Conjure.Representations.Common


msetExplicitVarSizeWithFlags :: forall m . (MonadFail m, NameGen m, EnumerateDomain m) => Representation m
msetExplicitVarSizeWithFlags = Representation chck downD structuralCons downC up

    where

        chck :: TypeOf_ReprCheck
        chck f (DomainMSet _ attrs innerDomain) =
            DomainMSet MSet_ExplicitVarSizeWithFlags attrs <$> f innerDomain
        chck _ _ = []

        nameFlag   = mkOutName MSet_ExplicitVarSizeWithFlags (Just "Flags")
        nameValues = mkOutName MSet_ExplicitVarSizeWithFlags (Just "Values")

        getMaxSize attrs innerDomain = case attrs of
            MSetAttr (SizeAttr_Size x) _ -> return x
            MSetAttr (SizeAttr_MaxSize x) _ -> return x
            MSetAttr (SizeAttr_MinMaxSize _ x) _ -> return x
            MSetAttr _ (OccurAttr_MaxOccur x) -> do y <- domainSizeOf innerDomain ; return (x * y)
            MSetAttr _ (OccurAttr_MinMaxOccur _ x) -> do y <- domainSizeOf innerDomain ; return (x * y)
            _ -> fail ("getMaxSize, mset not supported. attributes:" <+> pretty attrs)

        getMinOccur attrs = case attrs of
            MSetAttr _ (OccurAttr_MinOccur x) -> Just x
            MSetAttr _ (OccurAttr_MinMaxOccur x _) -> Just x
            _ -> Nothing

        getMaxOccur attrs = case attrs of
            MSetAttr _ (OccurAttr_MaxOccur x) -> return x
            MSetAttr _ (OccurAttr_MinMaxOccur _ x) -> return x
            MSetAttr (SizeAttr_Size x) _ -> return x
            MSetAttr (SizeAttr_MaxSize x) _ -> return x
            MSetAttr (SizeAttr_MinMaxSize _ x) _ -> return x
            _ -> fail ("getMaxOccur, mset not supported. attributes:" <+> pretty attrs)

        downD :: TypeOf_DownD m
        downD (name, DomainMSet _ attrs innerDomain) = do
            maxSize  <- getMaxSize attrs innerDomain
            maxOccur <- getMaxOccur attrs
            let indexDomain =           mkDomainIntB 1 maxSize
            let flagDomain  = defRepr $ mkDomainIntB 0 maxOccur
            return $ Just
                [ ( nameFlag name
                  , DomainMatrix indexDomain flagDomain
                  )
                , ( nameValues name
                  , DomainMatrix indexDomain innerDomain
                  )
                ]
        downD _ = na "{downD} ExplicitVarSizeWithFlags"

        structuralCons :: TypeOf_Structural m
        structuralCons f downX1 (DomainMSet MSet_ExplicitVarSizeWithFlags attrs@(MSetAttr sizeAttrs _) innerDomain) = do
            maxSize  <- getMaxSize attrs innerDomain
            let
                orderingWhenFlagged flags values = do
                    (iPat, i) <- quantifiedVar
                    return $ return $ -- list
                        [essence|
                            forAll &iPat : int(1..&maxSize-1) . &flags[&i+1] > 0 -> &values[&i] .< &values[&i+1]
                        |]

                dontCareWhenNotFlagged flags values = do
                    (iPat, i) <- quantifiedVar
                    return $ return $ -- list
                        [essence|
                            forAll &iPat : int(1..&maxSize) . &flags[&i] = 0 -> dontCare(&values[&i])
                        |]

                flagsToTheLeft flags = do
                    (iPat, i) <- quantifiedVar
                    return $ return $ -- list
                        [essence|
                            forAll &iPat : int(1..&maxSize-1) . &flags[&i+1] > 0 -> &flags[&i] > 0
                        |]

                cardinality flags = do
                    (iPat, i) <- quantifiedVar
                    return [essence| sum &iPat : int(1..&maxSize) . &flags[&i] |]

                -- maxOccur is enforced by the domain of the flag
                minOccurrenceCons flags = do
                    (iPat, i) <- quantifiedVar
                    return $
                        [ [essence| forAll &iPat : int(1..&maxSize) . &flags[&i] >= &minOccur |]
                        | Just minOccur <- [getMinOccur attrs]
                        ]

                innerStructuralCons flags values = do
                    (iPat, i) <- quantifiedVar
                    let activeZone b = [essence| forAll &iPat : int(1..&maxSize) . &flags[&i] > 0 -> &b |]

                    -- preparing structural constraints for the inner guys
                    innerStructuralConsGen <- f innerDomain

                    let inLoop = [essence| &values[&i] |]
                    outs <- innerStructuralConsGen inLoop
                    return (map activeZone outs)

            return $ \ mset -> do
                refs <- downX1 mset
                case refs of
                    [flags, values] ->
                        concat <$> sequence
                            [ orderingWhenFlagged    flags values
                            , dontCareWhenNotFlagged flags values
                            , flagsToTheLeft         flags
                            , minOccurrenceCons      flags
                            , mkSizeCons sizeAttrs <$> cardinality flags
                            , innerStructuralCons flags values
                            ]
                    _ -> na "{structuralCons} ExplicitVarSizeWithFlags"

        structuralCons _ _ _ = na "{structuralCons} ExplicitVarSizeWithFlags"

        downC :: TypeOf_DownC m
        downC ( name
              , domain@(DomainMSet _ attrs innerDomain)
              , ConstantAbstract (AbsLitMSet constants')
              ) = do
            maxSize <- getMaxSize attrs innerDomain
            let indexDomain = mkDomainIntB 1 maxSize

            let constants = histogram constants'

            maxSizeInt <-
                case maxSize of
                    ConstantInt x -> return x
                    _ -> fail $ vcat
                            [ "Expecting an integer for the maxSize attribute."
                            , "But got:" <+> pretty maxSize
                            , "When working on:" <+> pretty name
                            , "With domain:" <+> pretty domain
                            ]
            z <- zeroVal innerDomain
            let zeroes = replicate (fromInteger (maxSizeInt - genericLength constants)) z

            let counts = map (ConstantInt . snd) constants
            let falses = replicate (fromInteger (maxSizeInt - genericLength constants)) (ConstantInt 0)

            return $ Just
                [ ( nameFlag name
                  , DomainMatrix indexDomain DomainBool
                  , ConstantAbstract $ AbsLitMatrix indexDomain (counts ++ falses)
                  )
                , ( nameValues name
                  , DomainMatrix indexDomain innerDomain
                  , ConstantAbstract $ AbsLitMatrix indexDomain (map fst constants ++ zeroes)
                  )
                ]
        downC _ = na "{downC} ExplicitVarSizeWithFlags"

        up :: TypeOf_Up m
        up ctxt (name, domain) =
            case (lookup (nameFlag name) ctxt, lookup (nameValues name) ctxt) of
                (Just flagMatrix, Just constantMatrix) ->
                    case viewConstantMatrix flagMatrix of
                        -- TODO: check if indices match
                        Just (_, flags) ->
                            case viewConstantMatrix constantMatrix of
                                Just (_, vals) ->
                                    return (name, ConstantAbstract $ AbsLitMSet $ concat
                                                    [ replicate (fromInteger i) v
                                                    | (ConstantInt i,v) <- zip flags vals
                                                    ] )
                                _ -> fail $ vcat
                                        [ "Expecting a matrix literal for:" <+> pretty (nameValues name)
                                        , "But got:" <+> pretty constantMatrix
                                        , "When working on:" <+> pretty name
                                        , "With domain:" <+> pretty domain
                                        ]
                        _ -> fail $ vcat
                                [ "Expecting a matrix literal for:" <+> pretty (nameFlag name)
                                , "But got:" <+> pretty flagMatrix
                                , "When working on:" <+> pretty name
                                , "With domain:" <+> pretty domain
                                ]
                (Nothing, _) -> fail $ vcat $
                    [ "(in MSet ExplicitVarSizeWithFlags up 1)"
                    , "No value for:" <+> pretty (nameFlag name)
                    , "When working on:" <+> pretty name
                    , "With domain:" <+> pretty domain
                    ] ++
                    ("Bindings in context:" : prettyContext ctxt)
                (_, Nothing) -> fail $ vcat $
                    [ "(in MSet ExplicitVarSizeWithFlags up 2)"
                    , "No value for:" <+> pretty (nameValues name)
                    , "When working on:" <+> pretty name
                    , "With domain:" <+> pretty domain
                    ] ++
                    ("Bindings in context:" : prettyContext ctxt)
