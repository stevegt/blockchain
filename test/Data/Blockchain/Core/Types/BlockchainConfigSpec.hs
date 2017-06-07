module Data.Blockchain.Core.Types.BlockchainConfigSpec (spec) where

import TestUtil

import qualified Data.HashMap.Strict as H
import qualified Data.Time.Clock     as Time

import           Data.Blockchain.Core.Types

testConfig :: BlockchainConfig
testConfig = BlockchainConfig
    { initialDifficulty             = Difficulty 1000
    , targetSecondsPerBlock         = 60
    , difficultyRecalculationHeight = 10
    , initialMiningReward           = 100
    , miningRewardTransitionMap     = H.fromList [(5, 50), (20, 10)]
    }

spec :: Spec
spec = describe "Data.Blockchain.Core.Types.BlockchainConfig" $ do
    describe "targetReward" $ do
        it "should produce the correct reward" $
            and [ targetReward testConfig 0  == 100
                , targetReward testConfig 4  == 100
                , targetReward testConfig 5  == 50
                , targetReward testConfig 19 == 50
                , targetReward testConfig 20 == 10
                , targetReward testConfig 21 == 10
                ]

        prop "should always find a valid reward" $
            \conf height ->
                let possibleRewards = initialMiningReward conf : H.elems (miningRewardTransitionMap conf)
                in targetReward conf height `elem` possibleRewards

    describe "targetDifficulty" $ do
        prop "should use initial config when no blocks" $
            \conf -> targetDifficulty conf [] === initialDifficulty conf

        prop "should correctly adjust difficulty" $
            \block (Positive (n :: Int)) ->
                let ratio              = toRational n / 600
                    lastBlock          = adjustTime (Time.addUTCTime $ fromIntegral n) block
                    blocks             = replicate 9 block ++ pure lastBlock
                    lastDiff           = difficulty (blockHeader block)
                    expectedDifficulty = Difficulty $ round (toRational (unDifficulty lastDiff) * ratio)
                in targetDifficulty testConfig blocks === expectedDifficulty

        propWithSize 20 "should produce the correct difficulty when not recalculating" $
            \(NonEmpty blocks) conf ->
                  -- Pretty complex example, can it be cleaned up?
                  difficultyRecalculationHeight conf /= 0 &&
                  targetSecondsPerBlock conf /= 0 &&
                  length blocks `mod` fromIntegral (difficultyRecalculationHeight conf) /= 0
                  ==> targetDifficulty conf blocks === difficulty (blockHeader $ last blocks)

        prop "should always find a valid difficulty" $
            \conf blocks -> targetDifficulty conf blocks >= Difficulty 0 -- TODO: want >= diff 1


adjustTime :: (Time.UTCTime -> Time.UTCTime) -> Block -> Block
adjustTime f block = setTime (f $ time $ blockHeader block) block

setTime :: Time.UTCTime -> Block -> Block
setTime t (Block header tx txs) = Block (header {time = t}) tx txs
