module Model.Updates where

import Model.Model as Model
import Data.List
import Data.Ord
import Data.Maybe
import Control.Monad
import Model.Types
import System.Random.Shuffle
import System.Random
import Control.Applicative


-- show this in presentation
dealCards :: GameState -> GameState
dealCards gs@GameState{currentRound=round, pile=pile, players=players, stdGen = gen} =
  gs{pile=undealtCards, players=playersWithDealtCards, stdGen=gen'}
    where numberOfCards = (cardsPerRound Model.deck $ length players) !! round
          (shuffledDeck, gen') = (shuffle' Model.deck (length Model.deck) gen, snd $ next gen)
          chunked = sublist numberOfCards shuffledDeck
          playersWithDealtCards = map (\(chunk, player) -> player{hand=chunk, playedCard=Nothing}) (zip chunked players)
          undealtCards = concat $ drop (length players) chunked


--TODO replace player in wating for ... as well
replacePlayer :: Player -> PlayerState -> PlayerState
replacePlayer newPlayer ps@PlayerState{player=p} = ps{player=newPlayer}

replaceBotWithPlayer :: Player -> [PlayerState] -> [PlayerState]
replaceBotWithPlayer newPlayer [] = []
replaceBotWithPlayer newPlayer (p@PlayerState{player=plr}:ps) = case plr of
    (HumanPlayer _) -> p: (replaceBotWithPlayer newPlayer ps)
    (Ai _) -> p{player=newPlayer}: ps

replaceHumanPlayerWithBot :: Player -> Player -> [PlayerState] -> [PlayerState]
replaceHumanPlayerWithBot player bot ps = updatePlayer (\p -> p{player=bot}) player ps


reevaluatePlayersTurn :: GameState -> GameState
reevaluatePlayersTurn gs@GameState{phase = (WaitingForTricks p), players=players} = gs{phase = (WaitingForTricks $ player $ head players)}
reevaluatePlayersTurn gs@GameState{phase = (WaitingForCard p), players=players} = gs{phase = (WaitingForTricks $ player $ head players)}
reevaluatePlayersTurn gs@GameState{phase = (WaitingForColor p), players=players} = gs{phase = (WaitingForTricks $ player $ head players)}
reevaluatePlayersTurn gs = gs

cardsOnTable :: [PlayerState] -> Cards
cardsOnTable ps = catMaybes $ playedCard `fmap` ps

orElseList :: [a] -> [a] -> [a]
orElseList (x:xs) fallback = (x:xs)
orElseList [] fallback = fallback

cardsWithColor :: Cards -> Color -> Cards
cardsWithColor hand color = filter (\(Card v c) ->  c == color) hand

cardsPerRound :: Cards -> Int -> [Int]
cardsPerRound deck players =
  map (\x -> abs(x - rounds) + 1) [1..rounds * 2 - 1]
  where rounds = maxCardsPerPlayer deck players

maxCardsPerPlayer :: Cards -> Int -> Int
maxCardsPerPlayer deck numberOfPlayers =  (length deck) `div` numberOfPlayers

sublist :: Int -> [a] -> [[a]]
sublist n ls
    | n <= 0 || null ls = []
    | otherwise = take n ls:sublist n (drop n ls)

highestCard :: [(Player, Card)] -> Player
highestCard pcs = fst$ maximumBy (comparing(value . snd)) pcs

-- TODO avoid duplication
waitForColor :: GameState -> GameState
waitForColor gameState =  gameState{players = playerQueue, phase = WaitingForColor nextInLine, currentColor = Nothing}
  where playerQueue = nextPlayer(players gameState)
        nextInLine = (player . head) playerQueue

-- TODO avoid duplication
waitForNextTricks :: GameState -> GameState
waitForNextTricks gameState =  gameState{players = playerQueue, phase = WaitingForTricks nextInLine}
  where playerQueue = nextPlayer(players gameState)
        nextInLine = (player . head) playerQueue
-- TODO avoid duplication
waitForNextCard :: GameState -> GameState
waitForNextCard gameState =  gameState{players = playerQueue, phase = WaitingForCard nextInLine}
  where playerQueue = nextPlayer(players gameState)
        nextInLine = (player . head) playerQueue

clearPlayedCards :: GameState -> GameState
clearPlayedCards gameState =
  let players = Model.players gameState
      players' = map (\ps -> ps{playedCard=Nothing}) players
  in gameState {players = players'}

setNewTrump :: GameState -> GameState
setNewTrump gameState = gameState {trump= trump, pile = rest}
  where (trump, rest) = case pile gameState of
                        [] -> ((shuffle' Model.colors (length Model.colors) $ Model.stdGen gameState) !! 0, [])
                        (x:xs) -> (Model.color x, xs)

tricksPlayerUpdate :: Int -> Player -> [PlayerState] -> [PlayerState]
tricksPlayerUpdate tricks = updatePlayer $ tellTricks tricks

tellTricks :: Int -> PlayerState -> PlayerState
tellTricks tricks playerState = playerState{tricks = [tricks] ++ Model.tricks playerState }

cardPlayedUpdate :: Card -> Player -> [PlayerState] -> [PlayerState]
cardPlayedUpdate card = updatePlayer $ playCard card

playCard :: Card -> PlayerState -> PlayerState
playCard card playerState = playerState{playedCard=Just(card), hand= delete card (Model.hand playerState)}

updatePlayer :: (PlayerState->PlayerState) -> Player -> [PlayerState] -> [PlayerState]
updatePlayer f p ps = map (\x -> if player x == p then f(x) else x) ps

addPlayers :: [Player] -> GameState -> GameState
addPlayers newPlayers gs@GameState{players=players} = gs{players= players ++ (map initPlayerState newPlayers) }

initPlayerState player = PlayerState player Nothing [] [] [] []

nextPlayer :: [PlayerState] -> [PlayerState]
nextPlayer (p:ps) = ps ++ [p]
