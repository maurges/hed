module Edit.Execute
( runOneCommand
, runCommands
) where


import Control.Monad ((>=>))
import Data.Map.Strict (Map, member, insert, union, delete, keysSet, keys)
import Data.Text (pack)
import qualified Data.Set as Set
import qualified Data.Map.Strict as Map
import qualified Data.Text as Text
import qualified Data.Vector as Vector
import Edit.Command (Command(..), LinewiseMovement(..), CharacterMovement(..)
                    ,VSide(..), HSide(..))
import Edit.Effects (Buffer(..), Effects(..), EditAtom, EffectAtom, newCursor
                    ,editBody, editFileName, editCursors
                    ,writer, tell)


-- |Execute editor commands to modify a buffer
runOneCommand :: Command -> Buffer -> EditAtom
runOneCommand (AddLineSelection movement) = addLineSelection movement
runOneCommand (RemoveLineSelection movement) = removeLineSelection movement

runOneCommand DeleteLines = deleteLines

runOneCommand PrintBufferBody = printBufferBody
runOneCommand WriteBuffer = writeBuffer
runOneCommand (BadCommand errmsg) = badCommand errmsg

-- |Execute a line of commands monadically
runCommands :: [Command] -> Buffer -> EditAtom
runCommands = foldr (>=>) return . map runOneCommand


--- Line selection commands ---

incLines :: (Num a, Eq a) => a -> Map a b -> Map a b
incLines x = Map.fromAscList . map (addToFst x) . Map.toAscList -- mapKeys
    where addToFst x (a, b) = (a + x, b)

addLineSelection :: LinewiseMovement -> Buffer -> EditAtom
addLineSelection (AbsoluteNumber line) =
    return . editCursors (addLine line)
    where addLine line cur = if line `member` cur
                             then cur
                             else insert line newCursor cur
addLineSelection (RelativeNumber offset) =
    return . editCursors (addLines offset)
    where addLines offset cur = let addedCur = incLines offset cur
                                in union cur addedCur

removeLineSelection :: LinewiseMovement -> Buffer -> EditAtom
removeLineSelection (AbsoluteNumber line) =
    return . editCursors (delete line)
removeLineSelection (RelativeNumber offset) =
    return . editCursors (deleteLines offset)
    where deleteLines offset cur =
            let toDel = Set.map (+ offset) $ keysSet cur
            in Map.withoutKeys cur toDel


--- Line editing commands ---



-- Side-effectful commands

printBufferBody :: Buffer -> EditAtom
printBufferBody buf = writer (buf, [PrintBuffer buf])

writeBuffer :: Buffer -> EditAtom
writeBuffer buf = writer (buf, [WriteFile buf])

badCommand :: String -> Buffer -> EditAtom
badCommand errmsg buf = writer (buf, [ConsoleLog . pack $ errmsg])
