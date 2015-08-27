{-# LANGUAGE QuasiQuotes #-}

module Conjure.Representations.Matrix
    ( matrix
    ) where

-- conjure
import Conjure.Prelude
import Conjure.Language
import Conjure.Representations.Internal


-- | The matrix "representation rule".
--   This rule handles the plumbing for matrices.
matrix
    :: forall m . (MonadFail m, NameGen m)
    => ((Name, DomainX Expression) -> m (Maybe [(Name, DomainX Expression)]))
    -> ((Name, DomainC, Constant) -> m (Maybe [(Name, DomainC, Constant)]))
    -> ((Name, DomainC) -> [(Name, Constant)] -> m (Name, Constant))
    -> Representation m
matrix downD1 downC1 up1 = Representation chck matrixDownD structuralCons matrixDownC matrixUp

    where

        chck :: TypeOf_ReprCheck
        chck f (DomainMatrix indexDomain innerDomain) = DomainMatrix indexDomain <$> f innerDomain
        chck _ _ = []

        matrixDownD :: TypeOf_DownD m
        matrixDownD (name, DomainMatrix indexDomain innerDomain) = do
            mres <- downD1 (name, innerDomain)
            case mres of
                Nothing -> return Nothing
                Just mids -> return $ Just
                    [ (n, DomainMatrix indexDomain d) | (n, d) <- mids ]
        matrixDownD _ = na "{matrixDownD}"

        structuralCons :: TypeOf_Structural m
        structuralCons f _ (DomainMatrix indexDomain innerDomain) = do
            let
                innerStructuralCons inpMatrix = do
                    (iPat, i) <- quantifiedVar
                    let activeZone b = [essence| forAll &iPat : &indexDomain . &b |]

                    -- preparing structural constraints for the inner guys
                    innerStructuralConsGen <- f innerDomain

                    let inLoop r = [essence| &r[&i] |]
                    outs <- innerStructuralConsGen (inLoop inpMatrix)
                    return (map activeZone outs)

            return $ \ inpMatrix -> innerStructuralCons inpMatrix

        structuralCons _ _ _ = na "{structuralCons} matrix 2"

        -- TODO: check if indices are the same
        matrixDownC :: TypeOf_DownC m
        matrixDownC ( name
                   , DomainMatrix indexDomain innerDomain
                   , ConstantAbstract (AbsLitMatrix _indexDomain2 constants)
                   ) = do
            mids1
                :: [Maybe [(Name, DomainC, Constant)]]
                <- sequence [ downC1 (name, innerDomain, c) | c <- constants ]
            let mids2 = catMaybes mids1
            if null mids2                                       -- if all were `Nothing`s
                then return Nothing
                else
                    if length mids2 == length mids1             -- if all were `Just`s
                        then do
                            let
                                mids3 :: [(Name, DomainC, [Constant])]
                                mids3 = [ ( head [ n | (n,_,_) <- line ]
                                          , head [ d | (_,d,_) <- line ]
                                          ,      [ c | (_,_,c) <- line ]
                                          )
                                        | line <- transpose mids2
                                        ]
                            return $ Just
                                [ ( n
                                  , DomainMatrix indexDomain d
                                  , ConstantAbstract $ AbsLitMatrix indexDomain cs
                                  )
                                | (n, d, cs) <- mids3
                                ]
                        else
                            fail $ vcat
                                [ "This is weird. Heterogeneous matrix literal?"
                                , "When working on:" <+> pretty name
                                , "With domain:" <+> pretty (DomainMatrix indexDomain innerDomain)
                                ]
        matrixDownC _ = na "{matrixDownC}"

        matrixUp :: TypeOf_Up m
        matrixUp ctxt (name, DomainMatrix indexDomain innerDomain)= do

            mid1
                :: Maybe [(Name, DomainX Expression)]
                <- downD1 (name, fmap Constant innerDomain)

            case mid1 of
                Nothing ->
                    -- the inner domain doesn't require refinement
                    -- there needs to be a binding with "name"
                    -- and we just pass it through
                    case lookup name ctxt of
                        Nothing -> fail $ vcat $
                            [ "(in Matrix up 1)"
                            , "No value for:" <+> pretty name
                            , "With domain:" <+> pretty (DomainMatrix indexDomain innerDomain)
                            ] ++
                            ("Bindings in context:" : prettyContext ctxt)
                        Just constant -> return (name, constant)
                Just mid2 -> do
                    -- the inner domain needs refinement
                    -- there needs to be bindings for each name in (map fst mid2)
                    -- we find those bindings, call (up1 name inner) on them, then lift
                    mid3
                        :: [(Name, [Constant])]
                        <- forM mid2 $ \ (n, _) ->
                            case lookup n ctxt of
                                Nothing -> fail $ vcat $
                                    [ "(in Matrix up 2)"
                                    , "No value for:" <+> pretty n
                                    , "When working on:" <+> pretty name
                                    , "With domain:" <+> pretty (DomainMatrix indexDomain innerDomain)
                                    ] ++
                                    ("Bindings in context:" : prettyContext ctxt)
                                Just constant ->
                                    -- this constant is a ConstantMatrix, containing one component of the things to go into up1
                                    case viewConstantMatrix constant of
                                        Just (_, vals) -> return (n, vals)
                                        _ -> fail $ vcat
                                            [ "Expecting a matrix literal for:" <+> pretty n
                                            , "But got:" <+> pretty constant
                                            , "When working on:" <+> pretty name
                                            , "With domain:" <+> pretty (DomainMatrix indexDomain innerDomain)
                                            ]

                    let midNames     = map fst mid3
                    let midConstants = map snd mid3

                    mid4
                        :: [(Name, Constant)]
                        <- sequence
                            [ up1 (name, innerDomain) (zip midNames cs)
                            | cs <- transpose midConstants
                            ]
                    let values = map snd mid4
                    return (name, ConstantAbstract $ AbsLitMatrix indexDomain values)
        matrixUp _ _ = na "{matrixUp}"
