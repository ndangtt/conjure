{-# LANGUAGE QuasiQuotes #-}
module Conjure.Rules.Vertical.Permutation where
import Conjure.Rules.Import

rule_Cardinality :: Rule
rule_Cardinality = "permutation-cardinality" `namedRule` theRule where
  theRule po = do
        p                              <- match opTwoBars po
        TypePermutation{}              <- typeOf p
        Permutation_AsFunction         <- representationOf p
        DomainPermutation _ _ innerDom <- domainOf p
        [fun]                          <- downX1 p
        return
            ( "Vertical rule for permutation cardinality, AsFunction representation."
            , do
               (iPat, i) <- quantifiedVarOverDomain (forgetRepr innerDom)
               return $ reTag AnyTag $ [essence| 
                          sum([ toInt(&i != image(&fun, &i)) | &iPat : &innerDom ])
                                       |]
            )

rule_Defined :: Rule
rule_Defined = "permutation-defined" `namedRule` theRule where
  theRule po = do
        p                              <- match opDefined po
        TypePermutation{}              <- typeOf p
        Permutation_AsFunction         <- representationOf p
        [fun]                          <- downX1 p
        return
            ( "Vertical rule for permutation defined, AsFunction representation."
            , do
               return [essence| defined(&fun) |]
            )



rule_Comprehension :: Rule
rule_Comprehension = "permutation-comprehension-tuples{AsFunction}" `namedRule` theRule where
    theRule (Comprehension body gensOrConds) =  do
        (gocBefore, (pat, perm), gocAfter) <- matchFirst gensOrConds $ \ goc -> case goc of
            Generator (GenInExpr pat [essence| &perm |]  ) -> return (pat, perm)
            _ -> na "rule_Comprehension"
        TypePermutation{}                 <- typeOf perm
        Permutation_AsFunction <- representationOf perm
        [f] <- downX1 perm
        return
            ( "Vertical rule for permutation-comprehension"
            , do
                (lPat, l) <- quantifiedVar
                (rPat, r) <- quantifiedVar
                return $ Comprehension body 
                        $  gocBefore
                        ++ [ Generator (GenInExpr pat [essence| [(&l,&r) 
                                                                | (&lPat, &rPat) <- &f
                                                                , &l != &r] |])
                           ]
                        ++ gocAfter 
            )
    theRule _ = na "rule_Comprehension"


rule_Image :: Rule
rule_Image = "permutation-image{AsFunction}" `namedRule` theRule where
  theRule [essence| image(&p, &i) |] = do
    TypePermutation inner <- typeOf p 
    case match permutationLiteral p of
      Nothing -> do
        typeI <- typeOf i
        if typesUnify [inner, typeI] 
          then do
            [f] <- downX1 p
            return ( "Vertical rule for permutation application to a single value" 
                   , do
                     return [essence| [&i, catchUndef(image(&f,&i),0)][toInt(&i in defined(&f))+1] |]
                   )
          else if typeI `containsType` inner
                 then na "rule_Image"
                 else return ( "Vertical rule for permutation application to a type the permutation doesn't care about"
                             , do
                               return [essence| &i |]
                             )
      _ -> na "rule_Image"
  theRule _ = na "rule_Image"



