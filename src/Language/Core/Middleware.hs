module Language.Core.Middleware
    ( Middleware
    , runMiddlewareIO
    , runMiddleware
    , (~>)
    , middlewareInMaybe
    ) where

import Language.Core.Imports
import Language.Core.Definition

type Middleware m a b = a -> m b

runMiddlewareIO :: a -> (Middleware (CompT IO) a b) -> IO b
runMiddlewareIO x f = singleNote "runMiddlewareIO" <$> runCompIO def def (f x)

runMiddleware :: a -> Middleware (CompT Identity) a b -> (Either CompError b, CompState, CompLog)
runMiddleware x f = singleNote "runMiddleware" $ runComp def def (f x)
    -- case runComp def def (f x) of
    --     (Left  e,_,logs) -> (Left (nestedToDoc e), logs)
    --     (Right a,_,logs) -> (Right a             , logs)

singleNote :: String -> [a] -> a
singleNote _    [x] = x
singleNote note []  = error $ "[] " ++ note
singleNote note _   = error $ "_ "  ++ note

(~>) :: Monad m => Middleware m a b -> Middleware m b c -> Middleware m a c
f ~> g = \ x -> do
    y <- f x
    g y

middlewareInMaybe :: (Functor m, Monad m) => Middleware m a b -> Middleware m (Maybe a) (Maybe b)
middlewareInMaybe _ Nothing  = return Nothing
middlewareInMaybe f (Just x) = Just <$> f x

-- traceList :: [String] -> a -> a
-- traceList [] x = x
-- traceList (m:ms) x = trace m $ traceList ms x
