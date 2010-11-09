
module BuildBox.Aspect.Stats
	( Stats	(..)
	, makeStats
	, predStats
	, liftStats
	, liftStats2)
where
import BuildBox.Pretty
import BuildBox.Data.Dividable


-- | Statistics extracted from many-valued data.
data Stats a	
	= Stats
	{ statsMin	:: a
	, statsAvg	:: a
	, statsMax	:: a }
	deriving (Read, Show)

instance Pretty a => Pretty (Stats a) where
	ppr (Stats mi av mx)
		=   (ppr mi) <+> text "/" 
		<+> (ppr av) <+> text "/"
		<+> (ppr mx)


-- | Make statistics from a list of values.
makeStats :: (Real a, Dividable a) => [a] -> Stats a
makeStats xs
	= Stats (minimum xs)
		(sum xs `divide` (fromIntegral $ length xs)) 
		(maximum xs)


-- | Return `True` if the predicate matches any of the min, avg, max values.
predStats :: (a -> Bool) -> Stats a -> Bool
predStats f (Stats mi av mx) 
	= or [f mi, f av, f mx]


-- | Lift a function to each component of a `Stats`
liftStats :: (a -> b) -> Stats a -> Stats b
liftStats f (Stats mi av mx)
	= Stats (f mi) (f av) (f mx)


-- | Lift a binary function to each component of a `Stats`
liftStats2 :: (a -> b -> c) -> Stats a -> Stats b -> Stats c
liftStats2 f (Stats min1 avg1 max1) (Stats min2 avg2 max2)
	= Stats (f min1 min2) (f avg1 avg2) (f max1 max2)


	
