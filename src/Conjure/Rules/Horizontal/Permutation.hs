{-# LANGUAGE QuasiQuotes #-}
module Conjure.Rules.Horizontal.Permutation where
import Conjure.Rules.Import
import Data.List (cycle)
import Data.Permutation (size, fromCycles, toFunction)
import Conjure.Process.Enumerate ( enumerateDomain )


rule_Cardinality_Literal :: Rule
rule_Cardinality_Literal = "permutation-cardinality-literal" `namedRule` theRule where
  theRule p' = do
    p                              <- match opTwoBars p'
    (TypePermutation inner, elems) <- match permutationLiteral p 
    let i' = Constant . ConstantInt AnyTag . fromIntegral . size <$> fromCycles elems
    case i' of
      Left er -> fail $ "Permutation literal invalid." <++> stringToDoc (show er)
      Right i -> return
        ( "Vertical rule for permutation cardinality, AsFunction representation."
        , do
           return [essence| &i |]
        )

rule_Equality :: Rule
rule_Equality = "permutation-equality" `namedRule` theRule where
  theRule e = do
    (p,q)  <- match opEq e
    TypePermutation{} <- typeOf p
    TypePermutation{} <- typeOf q
    return ( "Horizontal rule for permutation equality"
           , do
              (rPat, r) <- quantifiedVar
              (lPat, l) <- quantifiedVar
              return [essence| and([ image(&p,&l) = &r | (&lPat,&rPat) <- &q]) |]
           )


rule_Permute_Comprehension_Tuples_Literal :: Rule
rule_Permute_Comprehension_Tuples_Literal = "permutation-comprehension-tuples{AsFunction}" `namedRule` theRule where
    theRule (Comprehension body gensOrConds) =  do
        (gocBefore, (pat, perm), gocAfter) <- matchFirst gensOrConds $ \ goc -> case goc of
            Generator (GenInExpr pat [essence| &perm |]  ) -> return (pat, perm)
            _ -> na "rule_Comprehension_Tuples_Literal"
        (TypePermutation inner, elems) <- match permutationLiteral perm 
        DomainPermutation _ _ innerD <- domainOf perm 
        let f' = toFunction <$> fromCycles elems 
        case f' of
          Left er -> fail $ "Permutation literal invalid." <++> stringToDoc (show er)
          Right f -> do 
            let outLiteral = make matrixLiteral
                    (TypeMatrix (TypeInt AnyTag) (TypeTuple [inner,inner])) innerD  
                                   [ AbstractLiteral (AbsLitTuple [de
                                                                  ,f de])
                                   | de <- join elems 
                                   ]
            return
              ( "Vertical rule for permutation-comprehension-tuples-literal"
              , do
                  return $ Comprehension body 
                          $  gocBefore
                          ++ [ Generator (GenInExpr pat [essence| &outLiteral|])
                             ]
                          ++ gocAfter 
              )
    theRule _ = na "rule_Comprehension_Tuples_Literal"

--
--
--rule_Compose :: Rule
--rule_Compose = "permutation-compose{rule_Compose}" `namedRule` theRule where
--  theRule [essence| image(compose(&g, &h),&i) |] = do
--    TypePermutation innerG <- typeOf g
--    TypePermutation innerH <- typeOf g
--    typeI <- typeOf i
--    if typesUnify [innerG, innerH, typeI]
--       then return
--            ( "Horizontal rule for permutation composition/application"
--            , do
--              return [essence| image(&g, image(&h,&i)) |]
--            )
--       else na "rule_Compose"
--  theRule _ = na "rule_Compose"
--
--
--rule_Permutation_Inverse :: Rule
--rule_Permutation_Inverse = "permutation-inverse{AsFunction}" `namedRule` theRule where
--    theRule [essence| inverse(&p1, &p2)|] = do
--        case p1 of WithLocals{} -> na "bubble-delay" ; _ -> return ()
--        case p2 of WithLocals{} -> na "bubble-delay" ; _ -> return ()
--        TypePermutation{}                 <- typeOf p1
--        TypePermutation{}                 <- typeOf p2
--        return
--            ( "Vertical rule for permutation-inverse, AsFunction representation"
--            , do
--                (iPat, i) <- quantifiedVar
--                return [essence|
--                        (forAll &iPat in &p1 . image(&p2,&i[2]) = &i[1])
--                            /\
--                        (forAll &iPat in &p2 . image(&p1,&i[2]) = &i[1])
--                      |] 
--            )
--    theRule _ = na "rule_Permutation_Equality"
--
--rule_Permute_Literal :: Rule
--rule_Permute_Literal = "permutation-image-literal{AsFunction}" `namedRule` theRule where
--  theRule [essence| image(&p, &i) |] = do
--    (TypePermutation inner, elems) <- match permutationLiteral p 
--    case i of WithLocals{} -> na "bubble-delay" ; _ -> return ()
--    typeI <- typeOf i
----    traceM $ show typeI
--    if typeI `containsType` inner
--      then do
--        if typesUnify [inner, typeI]
--           then do        
--               innerD <- domainOf i
--               let prmTup pt = take (length pt) $ zip (cycle pt) (drop 1 $ cycle pt)
--                   permTups = join $ prmTup <$> elems 
--               let outLiteral = make matrixLiteral
--                                   (TypeMatrix (TypeInt NoTag) (TypeTuple [inner,inner]))
--                                   (DomainInt NoTag [RangeBounded 1 (fromInt (genericLength permTups))])
--                                   [ AbstractLiteral (AbsLitTuple [a,b])
--                                   | (a,b) <- permTups 
--                                   ]
--               return
--                  ( "Horizontal rule for permutation literal application to a single value (image), AsFunction representation"
--                  , do
--                    (hName, h) <- auxiliaryVar
--                    (fPat, f)  <- quantifiedVar
--                    (tPat, t)  <- quantifiedVar
--                    (gPat, g)  <- quantifiedVar
--                    (ePat, _)  <- quantifiedVar
--                    return $ WithLocals 
--                               [essence| &h |]
--                              (AuxiliaryVars 
--                                [ Declaration (FindOrGiven LocalFind hName innerD)
--                                , SuchThat
--                                    [ [essence| 
--                                          (forAll (&fPat, &tPat) in &outLiteral . &f = &i <-> &h = &t)
--                                       /\ (!(exists (&gPat, &ePat) in &outLiteral . &g = &h) <-> &h = &i)
--                                      |]
--                                    ]
--                                ]
--                              )
--                  )
--           else na "rule_Permute_Literal"
--      else return
--             ( "Horizontal rule for permutation application to a type the permutation doesn't care about"
--             , do
--               return [essence| &i |]
--             )
--  theRule _ = na "rule_Permute_Literal"
--
--
--rule_Permute_Literal_Comprehension :: Rule
--rule_Permute_Literal_Comprehension = "permutation-image-literal-comprehension{AsFunction}" `namedRule` theRule where
--  theRule (Comprehension body gensOrConds) = do
--    (gocBefore, (pat, p, i), gocAfter) <- matchFirst gensOrConds $ \ goc -> case goc of
--      Generator (GenInExpr pat [essence| image(&p, &i) |]) -> return (pat, p, i)
--      _ -> na "rule_Comprehension"
--    case i of WithLocals{} -> na "bubble-delay" ; _ -> return ()
--    (TypePermutation inner, elems) <- match permutationLiteral p 
--    typeI <- typeOf i
--    if typeI `containsType` inner
--      then do
--        if typesUnify [inner, typeI]
--           then do        
--               innerD <- domainOf i
--               let prmTup pt = take (length pt) $ zip (cycle pt) (drop 1 $ cycle pt)
--                   permTups = join $ prmTup <$> elems 
--               let outLiteral = make matrixLiteral
--                                   (TypeMatrix (TypeInt NoTag) (TypeTuple [inner,inner]))
--                                   (DomainInt NoTag [RangeBounded 1 (fromInt (genericLength permTups))])
--                                   [ AbstractLiteral (AbsLitTuple [a,b])
--                                   | (a,b) <- permTups 
--                                   ]
--               return
--                  ( "Horizontal rule for permutation literal application to a single value (image), AsFunction representation"
--                  , do
--                    (hName, h) <- auxiliaryVar
--                    (fPat, f)  <- quantifiedVar
--                    (tPat, t)  <- quantifiedVar
--                    (gPat, g)  <- quantifiedVar
--                    (ePat, _)  <- quantifiedVar
--                    return $ WithLocals 
--                              (Comprehension body $ gocBefore
--                                                ++ [Generator (GenInExpr pat
--                                                                [essence| &h |])]
--                                                ++ gocAfter)
--                              (AuxiliaryVars 
--                                [ Declaration (FindOrGiven LocalFind hName innerD)
--                                , SuchThat
--                                    [ [essence| 
--                                          (forAll (&fPat, &tPat) in &outLiteral . &f = &i <-> &h = &t)
--                                       /\ (!(exists (&gPat, &ePat) in &outLiteral . &g = &h) <-> &h = &i)
--                                      |]
--                                    ]
--                                ]
--                              )
--                  )
--           else na "rule_Permute_Literal"
--      else return
--             ( "Horizontal rule for permutation application to a type the permutation doesn't care about"
--             , return 
--                   (Comprehension body $ gocBefore
--                                     ++ [Generator (GenInExpr pat [essence| &i |])]
--                                     ++ gocAfter)
--             )
--  theRule _ = na "rule_Permute_Literal"
--
--