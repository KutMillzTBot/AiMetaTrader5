#property strict
#property description " kut milz Force Ai - SMC Engine (foundation build creator instaram: @Kut.milz)"
#property tester_indicator "Market\\KUTMilz.ex5"

#include <Trade/Trade.mqh>

#define FVG_PREFIX "FX_FVG_"
#define STRUCT_PREFIX "FX_STR_"

enum ENUM_BIAS
  {
   BIAS_NEUTRAL = 0,
   BIAS_BULL    = 1,
   BIAS_BEAR    = -1
  };

enum ENUM_EXEC_FLOW_STATE
  {
   FLOW_IDLE               = 0,
   FLOW_SWEEP_DETECTED     = 1,
   FLOW_CONFIRMATION       = 2,
   FLOW_ENTRY_READY        = 3,
   FLOW_EXECUTED           = 4,
   FLOW_MANAGING           = 5,
   FLOW_EXITED             = 6,
   // Legacy aliases kept for compatibility with existing code paths.
   FLOW_TREND_STATE        = FLOW_SWEEP_DETECTED,
   FLOW_PULLBACK_STATE     = FLOW_SWEEP_DETECTED,
   FLOW_LIQUIDITY_SWEEP    = FLOW_SWEEP_DETECTED,
   FLOW_CONFIRMATION_STATE = FLOW_CONFIRMATION,
   FLOW_EXECUTION_STATE    = FLOW_ENTRY_READY,
   FLOW_MANAGEMENT_STATE   = FLOW_MANAGING
  };

enum ENUM_SWING_LABEL
  {
   SWING_NONE = 0,
   SWING_HH   = 1,
   SWING_HL   = 2,
   SWING_LH   = 3,
   SWING_LL   = 4
  };

enum ENUM_MARKET_REGIME
  {
   REGIME_UNKNOWN = 0,
   REGIME_TREND   = 1,
   REGIME_RANGE   = 2,
   REGIME_HIGHVOL = 3
  };

enum Direction
  {
   DIR_SELL = -1,
   DIR_BUY  = 1
  };

#include "SignalEngine.mqh"
#include "RiskEngine.mqh"
#include "ExecutionEngine.mqh"
#include "ManagementEngine.mqh"

input group "General"
input ENUM_TIMEFRAMES InpExecutionTF            = PERIOD_M1;
input ENUM_TIMEFRAMES InpInternalTF             = PERIOD_M5;
input ENUM_TIMEFRAMES InpMacroTF                = PERIOD_M15;
input long            InpMagic                  = 20260212;
input bool            InpDeleteZonesOnInit      = false;

input group "Deriv V75 Profile"
input bool            InpEnableV75Profile       = true;
input bool            InpTradeOnlyV75Symbols    = false;
input bool            InpV75DisableSessionFilter= true;
input int             InpV75MinGapPoints        = 120;
input int             InpV751sMinGapPoints      = 80;
input int             InpV75InvalidationPoints  = 60;
input int             InpV751sInvalidationPoints= 40;
input int             InpV75MaxSpreadPoints     = 220;
input int             InpV751sMaxSpreadPoints   = 120;
input int             InpV75SlippagePoints      = 50;
input int             InpV751sSlippagePoints    = 35;
input int             InpV75OrderRetries        = 3;
input int             InpV751sOrderRetries      = 4;
input int             InpV75MaxTradesPerDay     = 0;
input int             InpV751sMaxTradesPerDay   = 0;
input int             InpV75MinStopDistancePts  = 260;
input int             InpV751sMinStopDistancePts= 180;

input group "Crash 900 Profile"
input bool            InpEnableCrash900Profile     = true;
input int             InpCrash900MaxPositionBars   = 3;

input group "Structure Engine"
input bool            InpEnableStructureLabels      = true;
input ENUM_TIMEFRAMES InpStructureTF                = PERIOD_CURRENT;
input int             InpStructureLookbackBars      = 500;
input int             InpZZDepth                    = 12;
input int             InpZZDeviation                = 5;
input int             InpZZBackstep                 = 3;
input color           InpStructureLineColor         = clrDodgerBlue;
input color           InpStructureTextColor         = clrYellow;
input int             InpStructureFontSize          = 10;
input int             InpStructureLabelOffsetPoints = 20;

input group "Backend Telemetry"
input bool            InpEnableBackendTelemetry     = true;
input string          InpBackendApiBase             = "http://127.0.0.1:8787";
input int             InpBackendTimeoutMs           = 1500;
input int             InpBackendTelemetryEverySec   = 1;
input int             InpBackendStructurePoints     = 30;
input int             InpBackendFVGZones            = 20;

input group "FVG Engine"
input int             InpMinGapPoints           = 100;
input int             InpFVGRectBars            = 10;
input double          InpMinBodyDisplacementPct = 70.0;
input bool            InpUseVisibleBars         = true;
input int             InpLookbackBars           = 300;
input color           InpBullFVGColor           = clrLime;
input color           InpBearFVGColor           = clrRed;
input bool            InpRequireMTFOverlap      = false;
input ENUM_TIMEFRAMES InpFVGOverlapTF           = PERIOD_M5;

input group "Execution"
input bool            InpAllowBuy               = true;
input bool            InpAllowSell              = true;
input bool            InpOnePositionAtATime     = true;
input double          InpFixedLots              = 0.10;
input int             InpSLBufferPoints         = 20;
input double          InpRiskReward             = 2.0;
input bool            InpRemoveZoneAfterTouch   = true;
input int             InpInvalidationPoints     = 40;
input bool            InpUseInstitutionalStateModel = true;
input bool            InpInstitutionalRequireReady = false;
input double          InpExecutionMinConfidence  = 70.0;
input int             InpOppositeFVGInvalidationCount = 2;
input double          InpPartialProtectRetracePct = 15.0;
input double          InpFinalProtectRetracePct  = 95.0;
input int             InpPartialProtectMinPeakPts = 120;
input bool            InpUseV75DualSMCExecution  = true;
input bool            InpV75AggressiveEntry      = true;
input double          InpV75ConservativeRetracePct = 50.0;
input double          InpV75MinRR                = 3.0;
input int             InpV75SweepSLExtraPoints   = 30;
input double          InpV75InvalidationBodyPct  = 70.0;

input group "Simple Mode"
input bool            InpSimpleModeNoGates       = true;
input bool            InpSimpleOneTimeframe      = true;

input group "Execution Triggers"
input bool            InpTriggerLowerTouch      = true;
input bool            InpTriggerMidTouch        = true;
input bool            InpTriggerUpperTouch      = false;
input bool            InpTriggerRejectionCandle = true;
input bool            InpTriggerMomentumBreak   = false;
input int             InpMinTriggerHits         = 1;
input int             InpTriggerBufferPoints    = 8;
input int             InpTriggerTickDelay       = 2;
input int             InpTriggerExecuteTick     = 3;
input int             InpWickSweepMinPoints     = 8;
input bool            InpTriggerBlockOpposingImbalance = true;
input bool            InpTriggerDecisionLogs    = true;
input double          InpV75ViolenceMultiplier  = 1.5;
input int             InpV75ViolenceLookback    = 10;
input bool            InpV75EnableFVGInversion  = true;
input bool            InpV75EnableDoubleSweep   = true;

input group "KUTMilz Signal"
input bool            InpUseCrystalHeikinSignal      = true;
input string          InpCrystalIndicatorPath        = "Market\\KUTMilz";
input ENUM_TIMEFRAMES InpCrystalSignalTF             = PERIOD_CURRENT;
input int             InpCrystalBuyBuffer            = 0;
input int             InpCrystalSellBuffer           = 1;
input bool            InpCrystalSignalUseNonEmpty    = true;
input bool            InpCrystalUseColorFallback     = true;
input int             InpCrystalHAOpenBuffer         = 2;
input int             InpCrystalHACloseBuffer        = 3;
input int             InpCrystalSignalShift          = 1;
input int             InpCrystalConfirmCandles       = 0;
input bool            InpCrystalOneSignalPerBar      = true;
input bool            InpCrystalInvertSignal         = false;
input bool            InpUseKUTMilzCleanSetupOnly    = true;
input bool            InpKUTMilzBypassEntryBlocks    = true;
input bool            InpKUTMilzExitOnOppositeCandle = true;
input bool            InpKUTMilzMasterExecutionOverride = true;
input int             InpKUTMilzSwingWing            = 2;
input int             InpKUTMilzSwingLookback        = 180;

input group "Weighted Confirmation"
input bool            InpUseWeightedConfirmation = true;
input int             InpConfirmScoreThreshold   = 6;
input int             InpPartialScoreThreshold   = 4;
input double          InpPartialEntryLotFactor   = 0.60;
input bool            InpUseAdaptiveConfirmThreshold = true;
input bool            InpEntryScoreLogs          = true;

input group "Weighted Confirmation Profile Tuning"
input bool            InpUseProfileSpecificScoreThresholds = true;
input int             InpConfirmScoreThresholdV75   = 6;
input int             InpPartialScoreThresholdV75   = 4;
input int             InpConfirmScoreThresholdV751s = 7;
input int             InpPartialScoreThresholdV751s = 5;
input int             InpStrongConfirmThresholdAdd  = 1;
input int             InpStrongPartialThresholdAdd  = 0;
input int             InpScalpConfirmThresholdAdd   = 0;
input int             InpScalpPartialThresholdAdd   = 0;
input double          InpPartialEntryLotFactorV75   = 0.65;
input double          InpPartialEntryLotFactorV751s = 0.45;
input double          InpStrongPartialLotFactor     = 0.70;
input double          InpScalpPartialLotFactor      = 0.50;
input double          InpScoreTrendMulV75           = 1.10;
input double          InpScoreTrendMulV751s         = 0.85;
input double          InpScoreLiquidityMulV75       = 0.90;
input double          InpScoreLiquidityMulV751s     = 1.20;
input double          InpScoreInstitutionalMulV75   = 1.10;
input double          InpScoreInstitutionalMulV751s = 0.85;
input double          InpScoreFvgMulV75             = 0.95;
input double          InpScoreFvgMulV751s           = 1.10;
input double          InpScorePhaseMulV75           = 1.00;
input double          InpScorePhaseMulV751s         = 1.15;
input double          InpScoreAccelPenaltyV75       = 0.80;
input double          InpScoreAccelPenaltyV751s     = 1.20;

input group "Entry Acceleration Filter"
input bool            InpUseEntryAccelerationFilter = true;
input double          InpAccelBodyPctMin         = 55.0;
input double          InpAccelVolumeRatioMin     = 1.05;
input double          InpAccelDisplacementRatioMin = 1.10;

input group "RR Execution Management"
input bool            InpUseRR1PartialAndBE      = false;
input double          InpRR1PartialClosePct      = 50.0;
input int             InpRR1BEOffsetPoints       = 2;
input double          InpTPAtrMultiplier         = 1.20;
input double          InpTPRangeExpansionMult    = 1.10;

input group "Loss Learning (Loss-Only)"
input bool            InpEnableLossLearning         = true;
input double          InpLossLearnMinLossUSD        = 0.50;
input double          InpLossLearnConfidenceStep    = 1.5;
input int             InpLossLearnTriggerBufStep    = 1;
input int             InpLossLearnTickDelayStep     = 1;
input double          InpLossLearnViolenceStep      = 0.05;
input int             InpLossLearnSweepSLStep       = 5;
input int             InpLossLearnStreakForHardening= 2;
input double          InpLossLearnMaxConfidenceAdd  = 25.0;
input int             InpLossLearnMaxTriggerBufAdd  = 20;
input int             InpLossLearnMaxTickDelayAdd   = 4;
input double          InpLossLearnMaxViolenceAdd    = 1.0;
input int             InpLossLearnMaxSweepSLAdd     = 120;
input bool            InpLossLearnPersistState      = true;
input bool            InpLossLearnResetOnInit       = false;

input group "Pattern Model"
input bool            InpEnablePatternModel     = true;
input int             InpPatternLookbackBars    = 14;
input double          InpPatternMinScore        = 58.0;
input bool            InpPatternDynamicTrigger  = true;
input double          InpPatternWStructure      = 40.0;
input double          InpPatternWMomentum       = 35.0;
input double          InpPatternWVolatility     = 25.0;

input group "Confluence Filters"
input bool            InpUseBiasFilter          = true;
input bool            InpRequireLiquiditySweep  = true;
input int             InpSweepLookbackBars      = 20;
input bool            InpRequireOBAlignment     = false;
input double          InpMinAIScore             = 55.0;

input group "AI Score Weights"
input double          InpW_Bias                 = 20.0;
input double          InpW_Sweep                = 20.0;
input double          InpW_Displacement         = 20.0;
input double          InpW_FVGConfluence        = 20.0;
input double          InpW_OBAlignment          = 20.0;

input group "Risk Control"
input int             InpMaxTradesPerDay        = 3;
input double          InpDailyLossLimitMoney    = 0.0;
input double          InpDailyProfitTargetMoney = 0.0;
input bool            InpUseSessionFilter       = true;
input string          InpSessionStart           = "07:00";
input string          InpSessionEnd             = "22:00";

input group "Forensic Debug"
input bool            InpDebugMode                    = false;
input int             InpDebugSummaryEveryTrades      = 12;

input group "Strict State Machine"
input int             InpFlowStateTimeoutBars         = 20;
input double          InpFlowSpreadSpikeMultiplier    = 1.5;
input bool            InpFlowResetOnBiasFlip          = true;

input group "Regime Adaptive Engine"
input int             InpRegimeConfirmTrend           = 6;
input int             InpRegimeConfirmRange           = 6;
input int             InpRegimeConfirmHighVol         = 7;
input int             InpRegimeConfirmUnknown         = 99;
input int             InpRegimePartialTrend           = 4;
input int             InpRegimePartialRange           = 4;
input int             InpRegimePartialHighVol         = 5;
input int             InpRegimePartialUnknown         = 99;
input double          InpRegimeRiskPctTrend           = 0.80;
input double          InpRegimeRiskPctRange           = 0.55;
input double          InpRegimeRiskPctHighVol         = 0.45;

input group "Professional Risk Engine"
input double          InpDailyDrawdownLimitPct        = 4.0;
input int             InpConsecLossPauseCount         = 3;
input int             InpConsecLossPauseBars          = 12;
input double          MaxEquityDrawdownPercent        = 10.0;
input bool            InpAutoDisableWorstRegime       = false;

input group "Advanced Entry Filters"
input double          InpSpreadSpikeFilterMultiplier  = 1.5;
input double          InpVolatilityBurstAtrMult       = 3.0;
input int             InpMicroCompressionBars         = 6;
input double          InpMicroCompressionAtrFactor    = 0.35;

input group "USD Sweep Exit"
input bool            InpUseUSDPerTradeSweep    = true;
input double          InpUSDTakeProfitPerTrade  = 8.0;
input double          InpUSDLossCutPerTrade     = 6.0;
input bool            InpUseUSDBasketSweep      = false;
input double          InpUSDBasketTakeProfit    = 20.0;
input double          InpUSDBasketLossCut       = 15.0;

input group "Execution Market Model"
input bool            InpUseMarketModel         = true;
input int             InpMaxSpreadPoints        = 120;
input int             InpMaxTickAgeSec          = 5;
input int             InpSlippagePoints         = 30;
input int             InpOrderRetries           = 2;
input int             InpRetryDelayMs           = 250;
input int             InpStopSafetyExtraPoints  = 80;
input bool            InpUseInvalidStopsRescue  = true;
input int             InpRescueAttachAttempts   = 10;
input int             InpRescueAttachDelayMs    = 150;

input group "Strong Mode"
input bool            InpStrongMode                    = true;
input int             InpStrongMinAIScore              = 75;
input int             InpStrongMaxSpreadPoints         = 180;
input bool            InpStrongRequireMTFOverlap       = true;
input bool            InpStrongRequireBias             = true;
input bool            InpStrongRequireLiquiditySweep   = true;
input bool            InpStrongRequireOBAlignment      = false;
input int             InpStrongMaxZoneAgeBars          = 8;
input bool            InpStrongRequireRetestCandle     = true;
input int             InpStrongRetestTolerancePoints   = 20;
input int             InpBreakEvenTriggerPoints        = 120;
input int             InpBreakEvenOffsetPoints         = 5;
input bool            InpUseTrailingStop               = true;
input int             InpTrailingStartPoints           = 180;
input int             InpTrailingDistancePoints        = 120;

input group "First Move Protection"
input bool            InpUseFirstMoveBreakEven         = true;
input int             InpFirstMoveBreakEvenTriggerPoints = 1;
input bool            InpFirstMoveTrailAssist          = true;
input int             InpFirstMoveBreakEvenMinPoints   = 25;
input int             InpFirstMoveTrailAssistMinPoints = 45;

input group "Exit Guard"
input bool            InpUseInstitutionalSuspendClose  = false;
input bool            InpUseOppositeStrongCandleClose  = false;
input bool            InpUseUSDPerTradeSweepWithTP     = false;
input bool            InpUseTransitionSuspendClose      = false;
input bool            InpUseOppositeFVGSuspendClose    = false;
input bool            InpRespectSetSLTPForSoftCloses   = true;

input group "Scalp Mode"
input bool            InpScalpMode                     = false;
input double          InpScalpRiskReward               = 1.25;
input int             InpScalpSLBufferPoints           = 12;
input int             InpScalpMinTriggerHits           = 2;
input int             InpScalpMinAIScore               = 65;
input int             InpScalpBreakEvenTriggerPoints   = 55;
input int             InpScalpBreakEvenOffsetPoints    = 2;
input bool            InpScalpUseTrailingStop          = true;
input int             InpScalpTrailingStartPoints      = 80;
input int             InpScalpTrailingDistancePoints   = 50;
input int             InpScalpMaxPositionBars          = 20;

input group "Scalp Entry Orchestrator"
input bool            InpUseScalpAutoEntryTF           = true;
input ENUM_TIMEFRAMES InpScalpEntryTF                  = PERIOD_M1;
input bool            InpScalpSenseFromPhase4          = true;
input int             InpScalpSenseMinP4Score          = 72;
input bool            InpScalpSenseRequirePattern      = true;

input group "Trade Quality Control"
input bool            InpUseRegimeMode                 = true;
input int             InpRegimeLookbackBars            = 30;
input double          InpRegimeTrendThresholdPct       = 58.0;
input double          InpRegimeHighVolRatio            = 1.8;
input double          InpRegimeRangeConfidenceBoost    = 3.0;
input double          InpRegimeHighVolConfidenceBoost  = 7.0;
input double          InpRegimeTrendLotMultiplier      = 1.00;
input double          InpRegimeRangeLotMultiplier      = 0.85;
input double          InpRegimeHighVolLotMultiplier    = 0.65;
input bool            InpUseDynamicConfidence          = true;
input int             InpDynamicConfidenceDeals        = 24;
input int             InpDynamicConfidenceRefreshSec   = 30;
input double          InpDynamicConfTightenWinRate     = 0.45;
input double          InpDynamicConfRelaxWinRate       = 0.62;
input double          InpDynamicConfMaxAdd             = 12.0;
input double          InpDynamicConfMaxReduce          = 6.0;
input bool            InpUseTimeStopExit               = true;
input int             InpTimeStopBars                  = 40;
input int             InpTimeStopHardLossBars          = 80;
input double          InpTimeStopMinProgressPts        = 18.0;
input bool            InpUseNoProgressExit             = true;
input int             InpNoProgressExitBars            = 8;
input double          InpNoProgressMinProgressPts      = 3.0;
input bool            InpUseSpreadToRangeGuard         = true;
input double          InpMaxSpreadToRangePct           = 35.0;
input bool            InpUseAtrRiskSizing              = false;
input double          InpRiskPerTradePct               = 0.35;
input int             InpAtrRiskPeriod                 = 14;
input double          InpAtrStopFloorMult              = 0.60;

input group "Setup Tag Engine"
input bool            InpUseSetupTagEngine             = true;
input int             InpTagMinSamples                 = 2;
input int             InpTagMaxConsecLosses            = 2;
input int             InpTagCooldownBars               = 10;
input bool            InpTagDecisionLogs               = true;

input group "Adaptive Trigger Engine"
input bool            InpUseAdaptiveTriggerModel       = true;
input int             InpAdaptiveLookbackBars          = 900;
input double          InpAdaptiveStrongScore           = 70.0;
input double          InpAdaptiveWeakScore             = 45.0;
input int             InpAdaptiveMaxHitsShift          = 1;
input double          InpAdaptiveToleranceShiftPct     = 15.0;
input int             InpAdaptiveTickDelayShift        = 1;
input bool            InpAdaptiveModelLogs             = true;
input int             InpAdaptiveLookbackBarsV75       = 900;
input int             InpAdaptiveLookbackBarsV751s     = 700;
input double          InpAdaptiveStrongScoreV75        = 68.0;
input double          InpAdaptiveWeakScoreV75          = 44.0;
input double          InpAdaptiveStrongScoreV751s      = 72.0;
input double          InpAdaptiveWeakScoreV751s        = 48.0;
input int             InpAdaptiveMaxHitsShiftV75       = 1;
input int             InpAdaptiveMaxHitsShiftV751s     = 1;
input double          InpAdaptiveToleranceShiftPctV75  = 18.0;
input double          InpAdaptiveToleranceShiftPctV751s= 12.0;
input int             InpAdaptiveTickDelayShiftV75     = 1;
input int             InpAdaptiveTickDelayShiftV751s   = 2;

input group "Manual SL/TP Protection"
input bool            InpProtectManualSLTPTrades       = true;
input string          InpManualTradeCommentTag         = "kutea26 manual";
input bool            InpManualProtectRequireBothSLTP  = false;
input bool            InpManualProtectByCommentOnly    = true;

input group "Fallback Trigger Flow"
input bool            InpUseStructureFallbackFlow      = true;
input int             InpFallbackLookbackBars          = 12;
input double          InpFallbackMinBodyPct            = 55.0;
input int             InpFallbackBreakBufferPoints     = 6;
input int             InpFallbackCooldownBars          = 6;
input bool            InpFallbackRequireBias           = true;

input group "Supervisor Phase2 Engine"
input bool            InpUseSupervisorPhase2           = true;
input int             InpSupervisorArmThreshold        = 45;
input int             InpSupervisorEnterThreshold      = 60;
input int             InpSupervisorCancelThreshold     = 35;
input int             InpSupervisorATRPeriod           = 14;
input double          InpSupervisorMinGapATR           = 0.20;
input int             InpSupervisorFakeConfirmBars     = 8;
input double          InpSupervisorFakeFillPct         = 75.0;
input bool            InpSupervisorBlockFakeFVG        = true;
input bool            InpSupervisorRequireLiqLikelihood= true;
input int             InpSupervisorLiqThreshold        = 40;
input bool            InpSupervisorDebugLogs           = false;

input group "Supervisor Phase3 Engine"
input bool            InpUseSupervisorPhase3           = true;
input double          InpSupervisorBosWeight           = 22.0;
input double          InpSupervisorChochWeight         = 30.0;
input bool            InpSupervisorRequireBosOrChochEntry = true;
input bool            InpSupervisorRequireBosOrChochFlow  = false;
input int             InpSupervisorRangeArmBoost       = 5;
input int             InpSupervisorRangeEnterBoost     = 8;
input int             InpSupervisorHighVolArmBoost     = 8;
input int             InpSupervisorHighVolEnterBoost   = 12;
input int             InpSupervisorRangeHitsAdd        = 1;
input int             InpSupervisorHighVolHitsAdd      = 1;
input bool            InpSupervisorPhase3Logs          = false;

input group "Supervisor Phase4 S&D Engine"
input bool            InpUseSupervisorPhase4           = true;
input int             InpSupervisorP4ArmThreshold      = 52;
input int             InpSupervisorP4EnterThreshold    = 64;
input int             InpSupervisorP4CancelThreshold   = 42;
input int             InpSupervisorP4HTFOverrideScore  = 85;
input int             InpSupervisorP4ATRPeriod         = 14;
input int             InpSupervisorP4SpreadMaxV75      = 80;
input int             InpSupervisorP4SpreadMaxV751s    = 140;
input double          InpSupervisorP4VolSpikeAtrV75    = 4.5;
input double          InpSupervisorP4VolSpikeAtrV751s  = 5.5;
input int             InpSupervisorP4SgbMinBaseCandles = 2;
input int             InpSupervisorP4SgbMaxBaseCandles = 6;
input double          InpSupervisorP4SgbMinDistAtr     = 0.5;
input double          InpSupervisorP4SgbMaxDistAtr     = 3.0;
input int             InpSupervisorP4FlippyMinRangePts = 500;
input int             InpSupervisorP4CplqSweepMinPts   = 200;
input int             InpSupervisorP4ThreeDriveTolPts  = 150;
input double          InpSupervisorP4W_HtfBias         = 30.0;
input double          InpSupervisorP4W_PatternQuality  = 25.0;
input double          InpSupervisorP4W_LiquiditySweep  = 20.0;
input double          InpSupervisorP4W_KingCandle      = 15.0;
input double          InpSupervisorP4W_StructureBreak  = 10.0;
input bool            InpSupervisorP4RequireCorePattern= true;
input bool            InpSupervisorP4Logs              = false;

input group "Supervisor Memory Layer"
input bool            InpUseSupervisorMemoryLayer      = true;
input int             InpMemoryLookbackBars            = 120;
input double          InpMemoryMinCandleSizeATR        = 1.5;
input bool            InpMemoryFilterByVolume          = false;
input double          InpMemoryMinVolumeRatio          = 1.5;
input double          InpMemoryBlendPct                = 25.0;
input int             InpMemoryMinScore                = 45;
input bool            InpMemoryRequireLiquiditySweep   = false;
input bool            InpMemoryLogs                    = false;

struct FVGZone
  {
   string   name;
   bool     bullish;
   datetime time1;
   datetime time2;
   double   lower;
   double   upper;
   double   gapPoints;
   double   bodyPct;
   int      anchorShift;
   bool     active;
   bool     traded;
   int      flowState;
   int      gateTicks;
   datetime gateBarTime;
   double   structureLevel;
   double   confidence;
   bool     fvgRespected;
   bool     fvgDisrespected;
   double   sweepWick;
   double   targetLiquidity;
   bool     doubleSweep;
   double   gapAtr;
   double   qualityScore;
   int      qualityTier; // 0=fake 1=weak 2=medium 3=strong
   bool     fakeConfirmed;
   double   liquidityLikelihood;
   double   alignmentScore;
   bool     bosAligned;
   bool     chochAligned;
   int      ageBars;
   bool     p4Sgb;
   bool     p4Flippy;
   bool     p4Compression;
   bool     p4Cplq;
   bool     p4ThreeDrive;
   bool     p4Qm;
   int      p4KingType; // 0=none 1=BE 2=Doji 3=DM 4=DR_BE
   double   p4PatternQuality;
   double   p4Score;
   bool     memDisplacement;
   bool     memUnfilled;
   bool     memStructure;
   bool     memLiquidity;
   double   memScore;
  };

struct PositionManageState
  {
   ulong  ticket;
   double peakProfitPts;
   bool   partialDone;
   bool   rr1Done;
  };

struct TagStatState
  {
   string   tag;
   int      closedSamples;
   int      wins;
   int      losses;
   int      consecutiveLosses;
   datetime pausedUntil;
  };

struct PositionTagMap
  {
   ulong  positionId;
   string tag;
  };

CTrade   g_trade;
FVGZone  g_zones[];
PositionManageState g_posManage[];
TagStatState g_tagStats[];
PositionTagMap g_positionTags[];
string   g_tagEvents[];

datetime g_lastExecBarTime = 0;
double   g_prevBid = 0.0;
double   g_prevAsk = 0.0;

int      g_dayKey = -1;
int      g_tradesToday = 0;
double   g_dayStartEquity = 0.0;
bool     g_dayLocked = false;

int      g_sessStartMins = -1;
int      g_sessEndMins = -1;
bool     g_sessionParsed = false;

int             g_zzHandle = INVALID_HANDLE;
ENUM_TIMEFRAMES g_structureTF = PERIOD_CURRENT;
string          g_structureTag = "";
datetime        g_lastStructureBarTime = 0;
int             g_crystalHandle = INVALID_HANDLE;
ENUM_TIMEFRAMES g_crystalTF = PERIOD_CURRENT;
datetime        g_lastCrystalBuyBar = 0;
datetime        g_lastCrystalSellBar = 0;
bool            g_isV75 = false;
bool            g_isV751s = false;
bool            g_isCrash900 = false;

double   g_adaptConfidenceAdd = 0.0;
int      g_adaptTriggerBufAdd = 0;
int      g_adaptTickDelayAdd = 0;
double   g_adaptViolenceAdd = 0.0;
int      g_adaptSweepSLAdd = 0;
int      g_lossStreak = 0;
int      g_lossLearnEvents = 0;
ulong    g_lastLearnDeal = 0;
string   g_backendSessionToken = "";
datetime g_lastTelemetrySent = 0;
datetime g_lastBackendLogTime = 0;
string   g_lastBackendLogMsg = "";
double   g_dynamicConfOffset = 0.0;
datetime g_lastDynamicConfRefresh = 0;
int      g_cachedRegime = REGIME_UNKNOWN;
datetime g_cachedRegimeBarTime = 0;
bool     g_modeStrongActive = false;
bool     g_modeScalpActive = false;
string   g_modeProfile = "BASE";
datetime g_lastAdaptiveModelBar = 0;
double   g_adaptModelBullScore = 50.0;
double   g_adaptModelBearScore = 50.0;
double   g_adaptModelTolMultBull = 1.0;
double   g_adaptModelTolMultBear = 1.0;
int      g_adaptModelHitsShiftBull = 0;
int      g_adaptModelHitsShiftBear = 0;
int      g_adaptModelTickDelayAdd = 0;
string   g_adaptModelStateTag = "NEUTRAL";
datetime g_lastFallbackSignalBar = 0;
datetime g_lastFallbackEntryBar = 0;
datetime g_lastTriggerDiagBar = 0;
datetime g_lastMasterSignalEvalBar = 0;

CFxSignalEngine      g_signalEngine;
CFxRiskEngine        g_riskEngine;
CFxExecutionEngine   g_execEngine;
CFxManagementEngine  g_manageEngine;

struct PerfStatBucket
  {
   int    trades;
   int    wins;
   double sumR;
   double sumHoldBars;
  };

PerfStatBucket g_perfRegime[4];
PerfStatBucket g_perfSession[4];
int            g_perfClosedCount = 0;
bool           g_regimeDisabled[4];
bool           g_enginesInited = false;

FVGZone   g_entryScoreCtxZone;
bool      g_entryScoreCtxReady = false;
double    g_entryScoreCtxPattern = 100.0;
double    g_entryScoreCtxAIScore = 0.0;
int       g_entryScoreCtxRegime = REGIME_UNKNOWN;
bool      g_entryScoreCtxInstReady = false;
bool      g_entryScoreCtxPhase2Pass = false;
bool      g_entryScoreCtxPhase4Pass = false;
bool      g_entryScoreCtxAccelPass = true;
double    g_entryScoreCtxSetupTagScore = 0.0;
bool      g_entryScoreCtxSetupTagBlocked = false;

bool BiasAllowsDirection(const bool bullish);
ENUM_BIAS DetectSimpleBias(const ENUM_TIMEFRAMES tf);
bool HasLiquiditySweep(const bool bullish);
bool HasMTFOverlap(const FVGZone &zone);
bool ValidateOrderBlockConfluence(const bool bullish,const FVGZone &zone);

struct SwingPoint
  {
   int    shift;
   double price;
   bool   isHigh;
   int    label;
  };

bool BuildRecentSwings(SwingPoint &swings[],const int lookback,const int wing);
bool GetBullTrendAndPullback(double &lastHL,double &prevHL,double &lastHH,double &prevHH,int &hlShift);
bool GetBearTransitionAndPullback(double &lastLH,double &lastHH,double &lastLL,double &prevHL,int &lhShift);
bool HasOpposingImbalanceNow(const bool bullish);
bool EvaluateInstitutionalStates(FVGZone &zone,const double bid,const double ask,string &stateTag);
double ComputeZoneGapAtr(const FVGZone &zone);
bool DetectRecentBOSCHOCH(const bool bullish,bool &bosOut,bool &chochOut);
int ComputeFVGQualityTier(FVGZone &zone);
bool IsFVGFakeConfirmed(const FVGZone &zone);
double ComputeLiquidityTakeLikelihood(const FVGZone &zone,const bool bullish);
double ComputeSupervisorAlignmentScore(FVGZone &zone,const bool bullish,const int triggerHits,const bool priceTrigger);
bool ApplySupervisorPhase2Gate(FVGZone &zone,const bool bullish,const int triggerHits,const bool priceTrigger,const bool forEntry,string &reason);
int GetSupervisorPhase3ThresholdBoost(const bool forEntry);
int GetSupervisorPhase3RequiredHits(const int baseHits);
int GetSupervisorP4SpreadMaxPoints();
double GetSupervisorP4VolSpikeThreshold();
bool DetectSupervisorP4KingCandle(const bool bullish,int &kingType,double &quality);
bool DetectSupervisorP4Compression(const bool bullish,double &quality);
bool DetectSupervisorP4Flippy(const FVGZone &zone,const bool bullish,double &quality);
bool DetectSupervisorP4ThreeDrive(const bool bullish,double &quality);
bool DetectSupervisorP4QM(const bool bullish,double &quality);
bool DetectSupervisorP4SGB(const FVGZone &zone,const bool bullish,double &quality);
bool DetectSupervisorP4CPLQ(const FVGZone &zone,const bool bullish,const bool hasCompression,double &quality);
double ComputeSupervisorPhase4Score(FVGZone &zone,const bool bullish);
bool ApplySupervisorPhase4Gate(FVGZone &zone,const bool bullish,const bool forEntry,string &reason,string &tagOut);
double ComputeMemoryLayerScore(FVGZone &zone,const bool bullish);
void SetEntryScoreContext(const FVGZone &zone,
                          const double patternScore,
                          const double aiScore,
                          const int regime,
                          const bool instReady,
                          const bool phase2Pass,
                          const bool phase4Pass,
                          const bool accelPass,
                          const double setupTagScore,
                          const bool setupTagBlocked);
double GetDynamicConfidenceScoreOffset();
int GetAdaptiveConfirmThreshold(const int baseThreshold);
double ComputeSetupTagScore(const string tag);
bool PassAccelerationFilter(const bool bullish,double &bodyPct,double &volRatio,double &dispRatio);
void GetScoreProfileFactors(double &trendMul,double &liqMul,double &instMul,double &fvgMul,double &phaseMul,double &accelPenaltyMul);
int GetProfileBaseThreshold(const bool partialThreshold);
double GetProfilePartialLotFactor();
int CalculateEntryScore(Direction dir);
bool ShouldSuspendPositionNow(const long pType,string &reason);
void PrunePositionManageState();
int FindPositionManageStateIndex(const ulong ticket,const bool create);
ENUM_TIMEFRAMES ResolveCrystalSignalTF();
bool InitCrystalSignalEngine();
void ReleaseCrystalSignalEngine();
bool ReadCrystalSignalFlags(const int shift,bool &buySignal,bool &sellSignal,datetime &barTime,string &reason);
bool ConfirmCrystalSignal(const bool bullish,string &reason,string &tagOut,datetime &signalBarTimeOut);
bool IsBullishCandleAt(const int shift);
bool IsBearishCandleAt(const int shift);
int GetSwingLabelAtShift(const int shift,const int wing,const int lookback,double &priceOut);
bool IsHigherHighAtShift(const int shift,const int wing,const int lookback,double &hhPriceOut);
bool IsCrash900ProfileActive();
bool PassKUTMilzCleanSetup(const bool bullish,const int signalShift,string &reason,string &tagOut);
bool ExecuteImmediateSignalOrder(FVGZone &zone,const datetime signalBarTime,const string signalTag);
bool IsMasterExecutionMode();
bool HasOpenMagicPositionDirection(const bool bullish);
bool CloseOppositeMagicPositionsForMaster(const bool bullish);
bool TryMasterExecutionEntryOnBarClose();
bool CrossedBullLevel(const double prevBid,const double bid,const double level,const double tol);
bool CrossedBearLevel(const double prevAsk,const double ask,const double level,const double tol);
bool IsScalpContext(const FVGZone &zone);
ENUM_TIMEFRAMES GetEntrySignalTF(const FVGZone &zone);
bool ConfirmScalpLowerTF(const FVGZone &zone,const double bid,const double ask,const double tol,string &tagOut);
bool BullRejectionAtLevelTF(const double level,const double tol,const ENUM_TIMEFRAMES tf);
bool BearRejectionAtLevelTF(const double level,const double tol,const ENUM_TIMEFRAMES tf);
bool BullRejectionAtLevel(const double level,const double tol);
bool BearRejectionAtLevel(const double level,const double tol);
bool TryStructureFallbackEntry(const double bid,const double ask);
bool GetRecentSwingLevel(const ENUM_TIMEFRAMES tf,const bool high,const int lookback,double &level,int &shift);
bool IsViolentDisplacement(const bool bullish,const int shift,double &ratioOut);
bool EvaluateV75DualSMCStates(FVGZone &zone,const double bid,const double ask,string &stateTag);
bool IsV75FVGInversionSell(const FVGZone &zone);
double GetAdaptiveExecutionMinConfidence();
int GetAdaptiveTriggerBufferPoints();
int GetAdaptiveTriggerTickDelay();
double GetAdaptiveViolenceMultiplier();
int GetAdaptiveSweepSLExtraPoints();
string LossLearnKey(const string suffix);
void ResetLossLearningState();
void SaveLossLearningState();
bool LoadLossLearningState();
void LearnFromLosingDeal(const ulong dealTicket);
string TrimBackendBase(const string baseUrl);
string JsonEscape(const string value);
string LabelToText(const int label);
string TimeframeToApiTag(const ENUM_TIMEFRAMES tf);
void LogTelemetryStatus(const string msg);
int CountOpenPositionsForMagicSymbol(const long magic,const string symbol);
string BuildTelemetryPayload();
bool ExtractJsonToken(const string json,const string key,string &valueOut);
bool FetchBackendSessionToken();
bool PostTelemetryPayload(const string payload);
void SendBackendTelemetry(const bool force);
int DetectMarketRegime();
int GetCurrentMarketRegime();
string RegimeToText(const int regime);
double GetRegimeConfidenceOffset();
double GetRegimeLotMultiplier();
void RefreshDynamicConfidenceOffset();
double ComputePointValuePerLot();
double ComputeATRPoints(const int period);
double ComputeRiskSizedVolume(const bool bullish,const MqlTick &tick,const double sl,const double fallbackLots);
string BuildSetupTag(const FVGZone &zone,const string patternPhase,const int regime);
int FindTagStatIndex(const string tag,const bool create);
int FindPositionTagIndex(const ulong positionId);
void LinkPositionTag(const ulong positionId,const string tag);
string PopPositionTag(const ulong positionId,const bool removeRow);
bool AttachResultDealToTag(const string tag);
bool IsSetupTagBlocked(const string tag,string &reason);
void QueueTagEvent(const string msg);
void UpdateSetupTagOutcomeFromDeal(const ulong dealTicket);
void ResolveModeProfile();
bool IsStrongModeActive();
bool IsScalpModeActive();
void RefreshAdaptiveTriggerModel();
int GetAdaptiveRequiredHitsShift(const bool bullish);
double GetAdaptiveToleranceMultiplier(const bool bullish);
string GetAdaptiveStateTag(const bool bullish);
int GetAdaptiveLookbackBarsEff();
double GetAdaptiveStrongScoreEff();
double GetAdaptiveWeakScoreEff();
int GetAdaptiveMaxHitsShiftEff();
double GetAdaptiveToleranceShiftPctEff();
int GetAdaptiveTickDelayShiftEff();
bool IsManualSLTPProtectedPosition();
bool HasProtectedManualPositionOpen();
bool CloseMagicPositionWithReason(const ulong ticket,const string reason,const double profitPts,const double profitUsd,const int ageBars);
bool CloseMagicPositionPartialWithReason(const ulong ticket,const double volume,const string reason,const double profitPts,const double profitUsd,const int ageBars);
int CurrentExecBarIndex();
double GetCurrentSpreadPoints();
double GetAverageSpreadPoints(const int lookbackBars);
double GetCurrentRangePoints(const int shift);
int GetSessionBucket(const datetime whenTime);
void UpdateFlowMachineGuards();
void RegisterPerformanceFromDeal(const ulong dealTicket);
void LogPerformanceSummaryIfDue();

string TrimBackendBase(const string baseUrl)
  {
   string out = baseUrl;
   while(StringLen(out) > 0)
     {
      const int c = (int)StringGetCharacter(out,0);
      if(c <= 32)
         out = StringSubstr(out,1);
      else
         break;
     }
   while(StringLen(out) > 0)
     {
      const int c = (int)StringGetCharacter(out,StringLen(out) - 1);
      if(c <= 32 || c == 47)
         out = StringSubstr(out,0,StringLen(out) - 1);
      else
         break;
     }
   return out;
  }

string JsonEscape(const string value)
  {
   string out = value;
   StringReplace(out,"\\","\\\\");
   StringReplace(out,"\"","\\\"");
   StringReplace(out,"\r"," ");
   StringReplace(out,"\n"," ");
   return out;
  }

string LabelToText(const int label)
  {
   switch(label)
     {
      case SWING_HH: return "HH";
      case SWING_HL: return "HL";
      case SWING_LH: return "LH";
      case SWING_LL: return "LL";
     }
   return "";
  }

string TimeframeToApiTag(const ENUM_TIMEFRAMES tf)
  {
   switch(tf)
     {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
     }
   return "M1";
  }

void LogTelemetryStatus(const string msg)
  {
   const datetime now = TimeLocal();
   if(msg == g_lastBackendLogMsg && (now - g_lastBackendLogTime) < 30)
      return;
   g_lastBackendLogMsg = msg;
   g_lastBackendLogTime = now;
   Print("ForceX Telemetry: ",msg);
  }

int CountOpenPositionsForMagicSymbol(const long magic,const string symbol)
  {
   int count = 0;
   const int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      count++;
     }
   return count;
  }

int CurrentExecBarIndex()
  {
   const int bars = Bars(_Symbol,InpExecutionTF);
   if(bars <= 0)
      return 0;
   return bars;
  }

double GetCurrentSpreadPoints()
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick))
      return 0.0;
   if(tick.bid <= 0.0 || tick.ask <= 0.0)
      return 0.0;
   return MathMax(0.0,(tick.ask - tick.bid) / _Point);
  }

double GetAverageSpreadPoints(const int lookbackBars)
  {
   const int lb = MathMax(4,lookbackBars);
   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   const int copied = CopyRates(_Symbol,InpExecutionTF,1,lb,rates);
   if(copied <= 0)
      return GetCurrentSpreadPoints();

   double sum = 0.0;
   int used = 0;
   for(int i = 0; i < copied; i++)
     {
      if(rates[i].spread <= 0)
         continue;
      sum += (double)rates[i].spread;
      used++;
     }

   if(used <= 0)
      return GetCurrentSpreadPoints();
   return (sum / used);
  }

double GetCurrentRangePoints(const int shift)
  {
   const double h = iHigh(_Symbol,InpExecutionTF,shift);
   const double l = iLow(_Symbol,InpExecutionTF,shift);
   if(h <= 0.0 || l <= 0.0 || h <= l)
      return 0.0;
   return (h - l) / _Point;
  }

int GetSessionBucket(const datetime whenTime)
  {
   MqlDateTime dt;
   TimeToStruct(whenTime,dt);
   const int h = dt.hour;
   if(h >= 6 && h <= 10)
      return 1; // London open window
   if(h >= 13 && h <= 17)
      return 2; // NY overlap window
   return 0; // off window
  }

void UpdateFlowMachineGuards()
  {
   const int barIdx = CurrentExecBarIndex();
   const double spreadPts = GetCurrentSpreadPoints();
   const double avgSpreadPts = GetAverageSpreadPoints(16);
   const ENUM_BIAS macroBias = DetectSimpleBias(InpMacroTF);
   g_signalEngine.SetTimeoutBars(MathMax(2,InpFlowStateTimeoutBars));
   g_signalEngine.UpdateGuards(barIdx,
                               spreadPts,
                               avgSpreadPts,
                               MathMax(1.05,InpFlowSpreadSpikeMultiplier),
                               macroBias,
                               InpFlowResetOnBiasFlip);
  }

void RegisterPerformanceFromDeal(const ulong dealTicket)
  {
   if(dealTicket == 0)
      return;
   if((long)HistoryDealGetInteger(dealTicket,DEAL_MAGIC) != InpMagic)
      return;
   if(HistoryDealGetString(dealTicket,DEAL_SYMBOL) != _Symbol)
      return;
   if((long)HistoryDealGetInteger(dealTicket,DEAL_ENTRY) != DEAL_ENTRY_OUT)
      return;

   const datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket,DEAL_TIME);
   const int regime = GetCurrentMarketRegime();
   const int rg = MathMax(0,MathMin(3,regime));
   const int sess = MathMax(0,MathMin(2,GetSessionBucket(dealTime)));
   const double pnl = HistoryDealGetDouble(dealTicket,DEAL_PROFIT) +
                      HistoryDealGetDouble(dealTicket,DEAL_SWAP) +
                      HistoryDealGetDouble(dealTicket,DEAL_COMMISSION);

   double refRiskMoney = 0.0;
   if(InpUseAtrRiskSizing && InpRiskPerTradePct > 0.0)
      refRiskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * (InpRiskPerTradePct / 100.0);
   if(refRiskMoney <= 0.0)
      refRiskMoney = MathMax(1.0,MathAbs(pnl));
   const double rMultiple = pnl / refRiskMoney;

   datetime posOpenTime = 0;
   const long posId = HistoryDealGetInteger(dealTicket,DEAL_POSITION_ID);
   if(posId > 0)
     {
      const int total = HistoryDealsTotal();
      for(int i = total - 1; i >= 0; i--)
        {
         const ulong d = HistoryDealGetTicket(i);
         if(d == 0)
            continue;
         if(HistoryDealGetInteger(d,DEAL_POSITION_ID) != posId)
            continue;
         if((long)HistoryDealGetInteger(d,DEAL_ENTRY) == DEAL_ENTRY_IN)
           {
            posOpenTime = (datetime)HistoryDealGetInteger(d,DEAL_TIME);
            break;
           }
        }
     }
   double holdBars = 0.0;
   if(posOpenTime > 0 && dealTime > posOpenTime)
     {
      const int sec = MathMax(1,PeriodSeconds(InpExecutionTF));
      holdBars = (double)(dealTime - posOpenTime) / sec;
     }

   g_perfRegime[rg].trades++;
   g_perfRegime[rg].sumR += rMultiple;
   g_perfRegime[rg].sumHoldBars += holdBars;
   if(pnl > 0.0)
      g_perfRegime[rg].wins++;

   g_perfSession[sess].trades++;
   g_perfSession[sess].sumR += rMultiple;
   g_perfSession[sess].sumHoldBars += holdBars;
   if(pnl > 0.0)
      g_perfSession[sess].wins++;

   g_perfClosedCount++;
  }

void LogPerformanceSummaryIfDue()
  {
   const int every = MathMax(1,InpDebugSummaryEveryTrades);
   if(!InpDebugMode || g_perfClosedCount <= 0 || (g_perfClosedCount % every) != 0)
      return;

   int worstRegime = -1;
   double worstExpectancy = DBL_MAX;
   for(int r = 0; r < 4; r++)
     {
      const int t = g_perfRegime[r].trades;
      if(t <= 0)
         continue;
      const double wr = 100.0 * (double)g_perfRegime[r].wins / (double)t;
      const double avgR = g_perfRegime[r].sumR / (double)t;
      const double avgHold = g_perfRegime[r].sumHoldBars / (double)t;
      PrintFormat("[PERF] regime=%s trades=%d winRate=%.1f%% avgR=%.2f avgHoldBars=%.1f",
                  RegimeToText(r),t,wr,avgR,avgHold);
      if(avgR < worstExpectancy && t >= every)
        {
         worstExpectancy = avgR;
         worstRegime = r;
        }
     }

   if(InpAutoDisableWorstRegime && worstRegime > 0 && worstRegime < ArraySize(g_regimeDisabled))
     {
      if(worstExpectancy < -0.20)
        {
         g_regimeDisabled[worstRegime] = true;
         PrintFormat("[PERF] auto-disabled regime=%s avgR=%.2f",RegimeToText(worstRegime),worstExpectancy);
        }
     }
  }

string BuildTelemetryPayload()
  {
   const int openPos = CountOpenPositionsForMagicSymbol(InpMagic,_Symbol);
   const int regime = GetCurrentMarketRegime();
   const string regimeTxt = RegimeToText(regime);
   int activeZones = 0;
   for(int i = 0; i < ArraySize(g_zones); i++)
      if(g_zones[i].active)
         activeZones++;

   string thinking = "Monitoring multi-trigger flow (structure, FVG, momentum)";
   string waitingFor = "Trigger alignment";
   string active = _Symbol + " | " + regimeTxt + " | zones=" + IntegerToString(activeZones);
   if(g_dayLocked)
     {
      thinking = "Risk lock active";
      waitingFor = "Next trading day reset";
      active = "Daily lock";
     }
   else if(openPos > 0)
     {
      thinking = "Managing open positions";
      waitingFor = "SL/TP, invalidation, or manual close";
      active = _Symbol + " | " + regimeTxt + " | open=" + IntegerToString(openPos);
     }
   else if(activeZones <= 0)
     {
      thinking = "Scanning for valid structure/FVG or fallback continuation";
      waitingFor = "Zone trigger stack or fallback breakout confirmation";
      active = _Symbol + " | " + regimeTxt + " | no active zones";
     }

   string pointsJson = "";
   SwingPoint swings[];
   const int lookback = MathMax(120,MathMin(900,InpStructureLookbackBars));
   const int maxPts = MathMax(1,InpBackendStructurePoints);
   if(BuildRecentSwings(swings,lookback,2))
     {
      const int n = ArraySize(swings);
      int labeledTotal = 0;
      for(int i = 0; i < n; i++)
         if(swings[i].label != SWING_NONE)
            labeledTotal++;
      int skip = MathMax(0,labeledTotal - maxPts);
      for(int i = 0; i < n; i++)
        {
         const string typ = LabelToText(swings[i].label);
         if(typ == "")
            continue;
         if(skip > 0)
           {
            skip--;
            continue;
           }
         const datetime t = iTime(_Symbol,InpExecutionTF,swings[i].shift);
         if(t <= 0)
            continue;
         if(StringLen(pointsJson) > 0)
            pointsJson += ",";
         pointsJson += "{\"type\":\"" + typ + "\",\"time\":" + IntegerToString((int)t) + ",\"price\":" + DoubleToString(swings[i].price,_Digits) + "}";
        }
     }

   string fvgJson = "";
   const int maxZones = MathMax(1,InpBackendFVGZones);
   int activeTotal = 0;
   for(int i = 0; i < ArraySize(g_zones); i++)
      if(g_zones[i].active)
         activeTotal++;
   int zoneSkip = MathMax(0,activeTotal - maxZones);
   for(int i = 0; i < ArraySize(g_zones); i++)
     {
      if(!g_zones[i].active)
         continue;
      if(zoneSkip > 0)
        {
         zoneSkip--;
         continue;
        }
      const double low = MathMin(g_zones[i].lower,g_zones[i].upper);
      const double high = MathMax(g_zones[i].lower,g_zones[i].upper);
      const string side = g_zones[i].bullish ? "bull" : "bear";
      if(StringLen(fvgJson) > 0)
         fvgJson += ",";
      fvgJson += "{\"side\":\"" + side + "\",\"t1\":" + IntegerToString((int)g_zones[i].time1) +
                 ",\"t2\":" + IntegerToString((int)g_zones[i].time2) + ",\"low\":" + DoubleToString(low,_Digits) +
                 ",\"high\":" + DoubleToString(high,_Digits) + "}";
     }

   ENUM_TIMEFRAMES tf = g_structureTF;
   if(tf == PERIOD_CURRENT)
      tf = (ENUM_TIMEFRAMES)Period();
   const string tfTag = TimeframeToApiTag(tf);

   string payload = "{";
   payload += "\"bot_state\":{";
   payload += "\"mode\":\"RUNNING\",";
   payload += "\"flow\":\"" + FxFlowStateToText(g_signalEngine.State()) + "\",";
   payload += "\"thinking\":\"" + JsonEscape(thinking) + "\",";
   payload += "\"waiting_for\":\"" + JsonEscape(waitingFor) + "\",";
   payload += "\"active\":\"" + JsonEscape(active) + "\"";
   payload += "},";
   payload += "\"structure\":[{";
   payload += "\"symbol\":\"" + JsonEscape(_Symbol) + "\",";
   payload += "\"tf\":\"" + tfTag + "\",";
   payload += "\"points\":[" + pointsJson + "],";
   payload += "\"fvg\":[" + fvgJson + "]";
   payload += "}],";
   payload += "\"tag_stats\":[";
   const int statsCount = ArraySize(g_tagStats);
   int tfSec = PeriodSeconds(InpExecutionTF);
   if(tfSec <= 0)
      tfSec = 60;
   const datetime nowTs = TimeCurrent();
   for(int i = 0; i < statsCount; i++)
     {
      if(i > 0)
         payload += ",";
      int barsLeft = 0;
      string status = "active";
      if(g_tagStats[i].pausedUntil > nowTs)
        {
         status = "paused";
         barsLeft = (int)((g_tagStats[i].pausedUntil - nowTs) / tfSec);
         if(((g_tagStats[i].pausedUntil - nowTs) % tfSec) > 0)
            barsLeft++;
         if(barsLeft < 0)
            barsLeft = 0;
        }
      payload += "{";
      payload += "\"tag\":\"" + JsonEscape(g_tagStats[i].tag) + "\",";
      payload += "\"samples\":" + IntegerToString(g_tagStats[i].closedSamples) + ",";
      payload += "\"wins\":" + IntegerToString(g_tagStats[i].wins) + ",";
      payload += "\"losses\":" + IntegerToString(g_tagStats[i].losses) + ",";
      payload += "\"consecutive_losses\":" + IntegerToString(g_tagStats[i].consecutiveLosses) + ",";
      payload += "\"paused_until\":" + IntegerToString((int)g_tagStats[i].pausedUntil) + ",";
      payload += "\"bars_left\":" + IntegerToString(barsLeft) + ",";
      payload += "\"status\":\"" + status + "\"";
      payload += "}";
     }
   payload += "],";
   payload += "\"tag_events\":[";
   const int tagCount = ArraySize(g_tagEvents);
   for(int i = 0; i < tagCount; i++)
     {
      if(i > 0)
         payload += ",";
      payload += "\"" + JsonEscape(g_tagEvents[i]) + "\"";
     }
   payload += "]";
   payload += "}";
   return payload;
  }

bool ExtractJsonToken(const string json,const string key,string &valueOut)
  {
   valueOut = "";
   const string pattern = "\"" + key + "\"";
   const int p = StringFind(json,pattern);
   if(p < 0)
      return false;
   const int colon = StringFind(json,":",p + StringLen(pattern));
   if(colon < 0)
      return false;
   const int q1 = StringFind(json,"\"",colon + 1);
   if(q1 < 0)
      return false;

   int q2 = -1;
   const int n = StringLen(json);
   for(int i = q1 + 1; i < n; i++)
     {
      const int ch = (int)StringGetCharacter(json,i);
      if(ch == 34)
        {
         const int prev = (i > q1 + 1) ? (int)StringGetCharacter(json,i - 1) : 0;
         if(prev != 92)
           {
            q2 = i;
            break;
           }
        }
     }
   if(q2 <= q1)
      return false;
   valueOut = StringSubstr(json,q1 + 1,q2 - q1 - 1);
   return (StringLen(valueOut) > 0);
  }

bool FetchBackendSessionToken()
  {
   const string base = TrimBackendBase(InpBackendApiBase);
   if(StringLen(base) < 10)
     {
      LogTelemetryStatus("backend url is empty/invalid");
      return false;
     }

   const string url = base + "/api/session";
   char req[];
   ArrayResize(req,0);
   char res[];
   string resHeaders = "";
   ResetLastError();
   const int code = WebRequest("GET",url,"",MathMax(400,InpBackendTimeoutMs),req,res,resHeaders);
   if(code == -1)
     {
      const int err = GetLastError();
      LogTelemetryStatus("session request failed, err=" + IntegerToString(err) + " (check MT5 WebRequest URL whitelist)");
      return false;
     }

   const string body = CharArrayToString(res,0,-1,CP_UTF8);
   if(code != 200)
     {
      LogTelemetryStatus("session http code " + IntegerToString(code));
      return false;
     }

   string token = "";
   if(!ExtractJsonToken(body,"token",token))
     {
      LogTelemetryStatus("session token parse failed");
      return false;
     }

   g_backendSessionToken = token;
   return true;
  }

bool PostTelemetryPayload(const string payload)
  {
   const string base = TrimBackendBase(InpBackendApiBase);
   if(StringLen(base) < 10)
      return false;

   if(StringLen(g_backendSessionToken) == 0)
      if(!FetchBackendSessionToken())
         return false;

   const string url = base + "/api/ea/telemetry";
   char req[];
   StringToCharArray(payload,req,0,-1,CP_UTF8);
   if(ArraySize(req) > 0 && req[ArraySize(req) - 1] == 0)
      ArrayResize(req,ArraySize(req) - 1);
   char res[];
   string resHeaders = "";
   string headers = "Content-Type: application/json\r\nX-KutEA-Session: " + g_backendSessionToken + "\r\n";

   ResetLastError();
   int code = WebRequest("POST",url,headers,MathMax(400,InpBackendTimeoutMs),req,res,resHeaders);
   if(code == 401)
     {
      g_backendSessionToken = "";
      if(FetchBackendSessionToken())
        {
         headers = "Content-Type: application/json\r\nX-KutEA-Session: " + g_backendSessionToken + "\r\n";
         ResetLastError();
         code = WebRequest("POST",url,headers,MathMax(400,InpBackendTimeoutMs),req,res,resHeaders);
        }
     }

   if(code == -1)
     {
      const int err = GetLastError();
      LogTelemetryStatus("telemetry request failed, err=" + IntegerToString(err) + " (check MT5 WebRequest URL whitelist)");
      return false;
     }
   if(code < 200 || code >= 300)
     {
      LogTelemetryStatus("telemetry http code " + IntegerToString(code));
      return false;
     }
   return true;
  }

void SendBackendTelemetry(const bool force)
  {
   if(!InpEnableBackendTelemetry)
      return;

   const int intervalSec = MathMax(1,InpBackendTelemetryEverySec);
   const datetime now = TimeLocal();
   if(!force && g_lastTelemetrySent > 0 && (now - g_lastTelemetrySent) < intervalSec)
      return;
   g_lastTelemetrySent = now;

   const string payload = BuildTelemetryPayload();
   if(PostTelemetryPayload(payload))
      ArrayResize(g_tagEvents,0);
  }

string BuildSetupTag(const FVGZone &zone,const string patternPhase,const int regime)
  {
   const string side = zone.bullish ? "BUY" : "SELL";
   const string tf = TimeframeToApiTag(InpExecutionTF);
   const string phase = (StringLen(patternPhase) > 0) ? patternPhase : "na";
   const string fvg = zone.fvgDisrespected ? "FVG_DIS" : (zone.fvgRespected ? "FVG_RES" : "FVG_NA");
   const string sweep = zone.doubleSweep ? "D2" : "D1";
   string q = "Q0";
   if(zone.qualityTier == 3)
      q = "Q3";
   else if(zone.qualityTier == 2)
      q = "Q2";
   else if(zone.qualityTier == 1)
      q = "Q1";
   const string a = "A" + IntegerToString((int)MathRound(zone.alignmentScore));
   const string p4 = "P4" + IntegerToString((int)MathRound(zone.p4Score));
   const string k4 = "K" + IntegerToString(zone.p4KingType);
   const string m4 = "M" + IntegerToString((int)MathRound(zone.memScore));
   return _Symbol + "|" + tf + "|" + RegimeToText(regime) + "|" + side + "|" + phase + "|" + fvg + "|" + sweep + "|" + q + "|" + a + "|" + p4 + "|" + k4 + "|" + m4;
  }

int FindTagStatIndex(const string tag,const bool create)
  {
   for(int i = 0; i < ArraySize(g_tagStats); i++)
      if(g_tagStats[i].tag == tag)
         return i;
   if(!create)
      return -1;
   const int n = ArraySize(g_tagStats);
   ArrayResize(g_tagStats,n + 1);
   g_tagStats[n].tag = tag;
   g_tagStats[n].closedSamples = 0;
   g_tagStats[n].wins = 0;
   g_tagStats[n].losses = 0;
   g_tagStats[n].consecutiveLosses = 0;
   g_tagStats[n].pausedUntil = 0;
   return n;
  }

int FindPositionTagIndex(const ulong positionId)
  {
   for(int i = 0; i < ArraySize(g_positionTags); i++)
      if(g_positionTags[i].positionId == positionId)
         return i;
   return -1;
  }

void LinkPositionTag(const ulong positionId,const string tag)
  {
   if(positionId == 0 || StringLen(tag) == 0)
      return;
   const int idx = FindPositionTagIndex(positionId);
   if(idx >= 0)
     {
      g_positionTags[idx].tag = tag;
      return;
     }
   const int n = ArraySize(g_positionTags);
   ArrayResize(g_positionTags,n + 1);
   g_positionTags[n].positionId = positionId;
   g_positionTags[n].tag = tag;
  }

string PopPositionTag(const ulong positionId,const bool removeRow)
  {
   const int idx = FindPositionTagIndex(positionId);
   if(idx < 0)
      return "";
   const string out = g_positionTags[idx].tag;
   if(removeRow)
     {
      const int last = ArraySize(g_positionTags) - 1;
      for(int i = idx; i < last; i++)
         g_positionTags[i] = g_positionTags[i + 1];
      ArrayResize(g_positionTags,last);
     }
   return out;
  }

void QueueTagEvent(const string msg)
  {
   const string line = "[TagEngine] " + msg;
   if(InpTagDecisionLogs)
      Print(line);
   const int n = ArraySize(g_tagEvents);
   ArrayResize(g_tagEvents,n + 1);
   g_tagEvents[n] = TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS) + " " + line;
   const int maxKeep = 40;
   if(ArraySize(g_tagEvents) > maxKeep)
     {
      const int extra = ArraySize(g_tagEvents) - maxKeep;
      for(int i = 0; i < maxKeep; i++)
         g_tagEvents[i] = g_tagEvents[i + extra];
      ArrayResize(g_tagEvents,maxKeep);
     }
  }

bool IsSetupTagBlocked(const string tag,string &reason)
  {
   reason = "";
   if(!InpUseSetupTagEngine)
      return false;
   const int idx = FindTagStatIndex(tag,false);
   if(idx < 0)
      return false;
   const datetime now = TimeCurrent();
   if(g_tagStats[idx].pausedUntil > 0)
     {
      if(now < g_tagStats[idx].pausedUntil)
        {
         reason = "tag cooldown active";
         return true;
        }
      g_tagStats[idx].pausedUntil = 0;
      g_tagStats[idx].consecutiveLosses = 0;
      QueueTagEvent("Resumed tag: " + tag);
     }
   return false;
  }

bool AttachResultDealToTag(const string tag)
  {
   if(!InpUseSetupTagEngine || StringLen(tag) == 0)
      return false;
   ulong posId = 0;
   const ulong dealTicket = (ulong)g_trade.ResultDeal();
   if(dealTicket > 0)
     {
      const datetime now = TimeCurrent();
      HistorySelect(now - 3600,now + 60);
      posId = (ulong)HistoryDealGetInteger(dealTicket,DEAL_POSITION_ID);
     }
   if(posId == 0)
     {
      ulong ticket = 0;
      long pType = -1;
      if(FindMagicPosition(ticket,pType))
         posId = ticket;
     }
   if(posId == 0)
      return false;
   LinkPositionTag(posId,tag);
   return true;
  }

void UpdateSetupTagOutcomeFromDeal(const ulong dealTicket)
  {
   if(!InpUseSetupTagEngine || dealTicket == 0)
      return;
   if((long)HistoryDealGetInteger(dealTicket,DEAL_ENTRY) != DEAL_ENTRY_OUT)
      return;
   if((long)HistoryDealGetInteger(dealTicket,DEAL_MAGIC) != InpMagic)
      return;
   if(HistoryDealGetString(dealTicket,DEAL_SYMBOL) != _Symbol)
      return;

   const ulong posId = (ulong)HistoryDealGetInteger(dealTicket,DEAL_POSITION_ID);
   if(posId == 0)
      return;

   if(PositionSelectByTicket(posId))
     {
      if((long)PositionGetInteger(POSITION_MAGIC) == InpMagic && PositionGetString(POSITION_SYMBOL) == _Symbol)
         return;
     }

   const string tag = PopPositionTag(posId,false);
   if(StringLen(tag) == 0)
      return;

   const datetime now = TimeCurrent();
   if(!HistorySelect(now - (datetime)(90 * 24 * 60 * 60),now))
      return;

   double pnl = 0.0;
   int outDeals = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
     {
      const ulong d = HistoryDealGetTicket(i);
      if(d == 0)
         continue;
      if((ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID) != posId)
         continue;
      if((long)HistoryDealGetInteger(d,DEAL_MAGIC) != InpMagic)
         continue;
      if(HistoryDealGetString(d,DEAL_SYMBOL) != _Symbol)
         continue;
      if((long)HistoryDealGetInteger(d,DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;
      pnl += HistoryDealGetDouble(d,DEAL_PROFIT) +
             HistoryDealGetDouble(d,DEAL_SWAP) +
             HistoryDealGetDouble(d,DEAL_COMMISSION);
      outDeals++;
     }
   if(outDeals <= 0)
      return;

   const int idx = FindTagStatIndex(tag,true);
   g_tagStats[idx].closedSamples++;
   if(pnl > 0.0)
     {
      g_tagStats[idx].wins++;
      g_tagStats[idx].consecutiveLosses = 0;
     }
   else
     {
      g_tagStats[idx].losses++;
      g_tagStats[idx].consecutiveLosses++;
     }

   const int minSamples = MathMax(1,InpTagMinSamples);
   const int maxConsec = MathMax(1,InpTagMaxConsecLosses);
   if(g_tagStats[idx].closedSamples >= minSamples && g_tagStats[idx].consecutiveLosses >= maxConsec)
     {
      const int bars = MathMax(1,InpTagCooldownBars);
      int sec = PeriodSeconds(InpExecutionTF);
      if(sec <= 0)
         sec = 60;
      g_tagStats[idx].pausedUntil = now + (datetime)(bars * sec);
      g_tagStats[idx].consecutiveLosses = 0;
      QueueTagEvent("Paused tag: " + tag + " after " + IntegerToString(maxConsec) + " consecutive losses. Cooldown " + IntegerToString(bars) + " bars.");
     }
   else
     {
      const string outcome = (pnl > 0.0) ? "WIN" : "LOSS";
      QueueTagEvent("Tag result: " + outcome + " | " + tag + " | pnl=" + DoubleToString(pnl,2) + " | samples=" + IntegerToString(g_tagStats[idx].closedSamples));
     }

   PopPositionTag(posId,true);
  }

int DetectMarketRegime()
  {
   if(!InpUseRegimeMode)
      return REGIME_UNKNOWN;

   const int bars = Bars(_Symbol,InpExecutionTF);
   const int lookback = MathMax(12,InpRegimeLookbackBars);
   if(bars < lookback + 5)
      return REGIME_UNKNOWN;

   int upStruct = 0;
   int dnStruct = 0;
   double rangeSum = 0.0;
   for(int i = 1; i <= lookback; i++)
     {
      const double h0 = iHigh(_Symbol,InpExecutionTF,i);
      const double h1 = iHigh(_Symbol,InpExecutionTF,i+1);
      const double l0 = iLow(_Symbol,InpExecutionTF,i);
      const double l1 = iLow(_Symbol,InpExecutionTF,i+1);
      if(h0 > h1 && l0 > l1)
         upStruct++;
      if(h0 < h1 && l0 < l1)
         dnStruct++;
      rangeSum += MathMax(h0 - l0,_Point);
     }

   const double trendPct = 100.0 * ((double)MathMax(upStruct,dnStruct) / (double)lookback);
   const double avgRange = rangeSum / lookback;
   const double currRange = MathMax(iHigh(_Symbol,InpExecutionTF,1) - iLow(_Symbol,InpExecutionTF,1),_Point);
   const double rangeRatio = currRange / MathMax(avgRange,_Point);

   if(rangeRatio >= MathMax(1.05,InpRegimeHighVolRatio))
      return REGIME_HIGHVOL;
   if(trendPct >= MathMax(40.0,InpRegimeTrendThresholdPct))
      return REGIME_TREND;
   return REGIME_RANGE;
  }

int GetCurrentMarketRegime()
  {
   if(!InpUseRegimeMode)
      return REGIME_UNKNOWN;

   const datetime barTime = iTime(_Symbol,InpExecutionTF,0);
   if(barTime > 0 && barTime == g_cachedRegimeBarTime)
      return g_cachedRegime;

   g_cachedRegime = DetectMarketRegime();
   g_cachedRegimeBarTime = barTime;
   return g_cachedRegime;
  }

string RegimeToText(const int regime)
  {
   switch(regime)
     {
      case REGIME_TREND: return "TREND";
      case REGIME_RANGE: return "RANGE";
      case REGIME_HIGHVOL: return "HIGHVOL";
     }
   return "UNKNOWN";
  }

double GetRegimeConfidenceOffset()
  {
   if(!InpUseRegimeMode)
      return 0.0;
   const int regime = GetCurrentMarketRegime();
   if(regime == REGIME_RANGE)
      return MathMax(0.0,InpRegimeRangeConfidenceBoost);
   if(regime == REGIME_HIGHVOL)
      return MathMax(0.0,InpRegimeHighVolConfidenceBoost);
   return 0.0;
  }

double GetRegimeLotMultiplier()
  {
   if(!InpUseRegimeMode)
      return 1.0;
   const int regime = GetCurrentMarketRegime();
   if(regime == REGIME_RANGE)
      return MathMax(0.1,InpRegimeRangeLotMultiplier);
   if(regime == REGIME_HIGHVOL)
      return MathMax(0.1,InpRegimeHighVolLotMultiplier);
   if(regime == REGIME_TREND)
      return MathMax(0.1,InpRegimeTrendLotMultiplier);
   return 1.0;
  }

void RefreshDynamicConfidenceOffset()
  {
   if(!InpUseDynamicConfidence)
     {
      g_dynamicConfOffset = 0.0;
      return;
     }

   const datetime now = TimeCurrent();
   const int refreshSec = MathMax(5,InpDynamicConfidenceRefreshSec);
   if(g_lastDynamicConfRefresh > 0 && (now - g_lastDynamicConfRefresh) < refreshSec)
      return;
   g_lastDynamicConfRefresh = now;

   const datetime from = now - (datetime)(45 * 24 * 60 * 60);
   if(!HistorySelect(from,now))
     {
      g_dynamicConfOffset = 0.0;
      return;
     }

   const int targetDeals = MathMax(8,InpDynamicConfidenceDeals);
   const int totalDeals = HistoryDealsTotal();
   int sampled = 0;
   int wins = 0;

   for(int i = totalDeals - 1; i >= 0 && sampled < targetDeals; i--)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if((long)HistoryDealGetInteger(deal,DEAL_MAGIC) != InpMagic)
         continue;
      if(HistoryDealGetString(deal,DEAL_SYMBOL) != _Symbol)
         continue;
      if((long)HistoryDealGetInteger(deal,DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;

      const double pnl = HistoryDealGetDouble(deal,DEAL_PROFIT) +
                         HistoryDealGetDouble(deal,DEAL_SWAP) +
                         HistoryDealGetDouble(deal,DEAL_COMMISSION);
      if(pnl > 0.0)
         wins++;
      sampled++;
     }

   if(sampled < 8)
     {
      g_dynamicConfOffset = 0.0;
      return;
     }

   const double winRate = (double)wins / (double)sampled;
   const double tightenAt = MathMax(0.05,MathMin(0.95,InpDynamicConfTightenWinRate));
   const double relaxAt = MathMax(tightenAt + 0.01,MathMin(0.98,InpDynamicConfRelaxWinRate));
   double offset = 0.0;

   if(winRate < tightenAt)
      offset = MathMin(MathMax(0.0,InpDynamicConfMaxAdd), (tightenAt - winRate) * 40.0);
   else if(winRate > relaxAt)
      offset = -MathMin(MathMax(0.0,InpDynamicConfMaxReduce), (winRate - relaxAt) * 28.0);

   g_dynamicConfOffset = offset;
  }

double ComputePointValuePerLot()
  {
   const double tickValueA = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   const double tickValueB = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE_PROFIT);
   const double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   const double tickValue = (tickValueA > 0.0 ? tickValueA : tickValueB);
   if(tickValue <= 0.0 || tickSize <= 0.0)
      return 0.0;
   return (_Point / tickSize) * tickValue;
  }

double ComputeATRPoints(const int period)
  {
   const int p = MathMax(2,period);
   const int bars = Bars(_Symbol,InpExecutionTF);
   if(bars < p + 5)
      return 0.0;

   double trSum = 0.0;
   int used = 0;
   for(int i = 1; i <= p; i++)
     {
      const double h = iHigh(_Symbol,InpExecutionTF,i);
      const double l = iLow(_Symbol,InpExecutionTF,i);
      const double pc = iClose(_Symbol,InpExecutionTF,i+1);
      const double tr1 = h - l;
      const double tr2 = MathAbs(h - pc);
      const double tr3 = MathAbs(l - pc);
      const double tr = MathMax(tr1,MathMax(tr2,tr3));
      trSum += MathMax(tr,_Point);
      used++;
     }
   if(used <= 0)
      return 0.0;
   return (trSum / used) / _Point;
  }

double ComputeRiskSizedVolume(const bool bullish,const MqlTick &tick,const double sl,const double fallbackLots)
  {
   if(!InpUseAtrRiskSizing)
      return NormalizeVolume(fallbackLots);

   if(InpRiskPerTradePct <= 0.0)
      return NormalizeVolume(fallbackLots);

   const double entry = bullish ? tick.ask : tick.bid;
   if(entry <= 0.0 || sl <= 0.0)
      return NormalizeVolume(fallbackLots);

   double stopPts = MathAbs(entry - sl) / _Point;
   if(stopPts <= 0.5)
      return NormalizeVolume(fallbackLots);

   if(InpAtrRiskPeriod > 2)
     {
      const int atrPeriod = MathMax(3,InpAtrRiskPeriod);
      const double atrPts = ComputeATRPoints(atrPeriod);
      if(atrPts > 0.0)
        {
         const double floorPts = atrPts * MathMax(0.1,InpAtrStopFloorMult);
         if(floorPts > stopPts)
            stopPts = floorPts;
        }
     }

   const double pointValue = ComputePointValuePerLot();
   if(pointValue <= 0.0)
      return NormalizeVolume(fallbackLots);

   double riskPct = MathMax(0.0,InpRiskPerTradePct);
   if(InpUseRegimeMode)
      riskPct = g_riskEngine.RegimeRiskPct(GetCurrentMarketRegime(),
                                           InpRegimeRiskPctTrend,
                                           InpRegimeRiskPctRange,
                                           InpRegimeRiskPctHighVol);

   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   const double riskMoney = equity * (riskPct / 100.0);
   if(riskMoney <= 0.0)
      return NormalizeVolume(fallbackLots);

   const double rawLots = riskMoney / (stopPts * pointValue);
   if(rawLots <= 0.0)
      return NormalizeVolume(fallbackLots);
   return NormalizeVolume(rawLots);
  }

int FindZoneByName(const string name)
  {
   for(int i = 0; i < ArraySize(g_zones); i++)
      if(g_zones[i].name == name)
         return i;
   return -1;
  }

void RemoveZoneByIndex(const int index,const bool deleteObject)
  {
   if(index < 0 || index >= ArraySize(g_zones))
      return;

   if(deleteObject)
      ObjectDelete(0,g_zones[index].name);

   const int last = ArraySize(g_zones) - 1;
   for(int i = index; i < last; i++)
      g_zones[i] = g_zones[i+1];

   ArrayResize(g_zones,last);
  }

int CountObjectsByPrefix(const string prefix)
  {
   int count = 0;
   const int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
     {
      const string name = ObjectName(0,i);
      if(StringFind(name,prefix) == 0)
         count++;
     }
   return count;
  }

void DeleteObjectsByPrefix(const string prefix)
  {
   const int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
     {
      const string name = ObjectName(0,i);
      if(StringFind(name,prefix) == 0)
         ObjectDelete(0,name);
     }
  }

bool InitStructureEngine()
  {
   if(!InpEnableStructureLabels)
      return true;

   if(InpSimpleModeNoGates && InpSimpleOneTimeframe)
      g_structureTF = InpExecutionTF;
   else
      g_structureTF = (InpStructureTF == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : InpStructureTF;
   g_structureTag = STRUCT_PREFIX + "TF" + IntegerToString((int)g_structureTF) + "_";
   g_lastStructureBarTime = 0;

   if(g_zzHandle != INVALID_HANDLE)
      IndicatorRelease(g_zzHandle);
   g_zzHandle = INVALID_HANDLE;

   g_zzHandle = iCustom(_Symbol,g_structureTF,"Examples\\ZigZag",InpZZDepth,InpZZDeviation,InpZZBackstep);
   if(g_zzHandle == INVALID_HANDLE)
      g_zzHandle = iCustom(_Symbol,g_structureTF,"ZigZag",InpZZDepth,InpZZDeviation,InpZZBackstep);

   return (g_zzHandle != INVALID_HANDLE);
  }

void ReleaseStructureEngine()
  {
   if(g_zzHandle != INVALID_HANDLE)
      IndicatorRelease(g_zzHandle);
   g_zzHandle = INVALID_HANDLE;
  }

ENUM_TIMEFRAMES ResolveCrystalSignalTF()
  {
   if(InpCrystalSignalTF == PERIOD_CURRENT || InpCrystalSignalTF <= 0)
      return InpExecutionTF;
   return InpCrystalSignalTF;
  }

bool InitCrystalSignalEngine()
  {
   ReleaseCrystalSignalEngine();

   g_crystalTF = ResolveCrystalSignalTF();
   g_lastCrystalBuyBar = 0;
   g_lastCrystalSellBar = 0;

   if(!InpUseCrystalHeikinSignal)
      return true;

   string indicatorPath = InpCrystalIndicatorPath;
   StringReplace(indicatorPath,"/","\\");
   if(StringLen(indicatorPath) <= 0)
      indicatorPath = "Market\\KUTMilz";

   string noExt = indicatorPath;
   StringReplace(noExt,".ex5","");

   // If a full filesystem path is provided, keep only the filename stem for iCustom.
   if(StringFind(noExt,":\\") >= 0)
     {
      int lastSlash = -1;
      const int n = StringLen(noExt);
      for(int i = n - 1; i >= 0; i--)
        {
         if(StringGetCharacter(noExt,i) == '\\')
           {
            lastSlash = i;
            break;
           }
        }
      if(lastSlash >= 0 && lastSlash + 1 < n)
         noExt = StringSubstr(noExt,lastSlash + 1);
     }

   const bool hasMarketPrefix = (StringFind(noExt,"Market\\") == 0);
   const string marketNoExt = hasMarketPrefix ? noExt : ("Market\\" + noExt);

   g_crystalHandle = iCustom(_Symbol,g_crystalTF,noExt);
   if(g_crystalHandle == INVALID_HANDLE)
      g_crystalHandle = iCustom(_Symbol,g_crystalTF,noExt + ".ex5");
   if(g_crystalHandle == INVALID_HANDLE)
      g_crystalHandle = iCustom(_Symbol,g_crystalTF,marketNoExt);
   if(g_crystalHandle == INVALID_HANDLE)
      g_crystalHandle = iCustom(_Symbol,g_crystalTF,marketNoExt + ".ex5");
   if(g_crystalHandle == INVALID_HANDLE)
      g_crystalHandle = iCustom(_Symbol,g_crystalTF,"Market\\KUTMilz");
   if(g_crystalHandle == INVALID_HANDLE)
      g_crystalHandle = iCustom(_Symbol,g_crystalTF,"Market\\KUTMilz.ex5");
   if(g_crystalHandle == INVALID_HANDLE)
      g_crystalHandle = iCustom(_Symbol,g_crystalTF,"KUTMilz");
   if(g_crystalHandle == INVALID_HANDLE)
      g_crystalHandle = iCustom(_Symbol,g_crystalTF,"KUTMilz.ex5");
   if(g_crystalHandle == INVALID_HANDLE)
      g_crystalHandle = iCustom(_Symbol,g_crystalTF,"Market\\Crystal Heikin Ashi");
   if(g_crystalHandle == INVALID_HANDLE)
      g_crystalHandle = iCustom(_Symbol,g_crystalTF,"Market\\Crystal Heikin Ashi.ex5");
   if(g_crystalHandle == INVALID_HANDLE)
      g_crystalHandle = iCustom(_Symbol,g_crystalTF,"Crystal Heikin Ashi");
   if(g_crystalHandle == INVALID_HANDLE)
      g_crystalHandle = iCustom(_Symbol,g_crystalTF,"Crystal Heikin Ashi.ex5");

   if(g_crystalHandle == INVALID_HANDLE)
      PrintFormat("ForceX Crystal init failed: indicator='%s' tf=%s",
                  InpCrystalIndicatorPath,TimeframeToApiTag(g_crystalTF));

   return (g_crystalHandle != INVALID_HANDLE);
  }

void ReleaseCrystalSignalEngine()
  {
   if(g_crystalHandle != INVALID_HANDLE)
      IndicatorRelease(g_crystalHandle);
   g_crystalHandle = INVALID_HANDLE;
  }

bool ReadCrystalSignalFlags(const int shift,bool &buySignal,bool &sellSignal,datetime &barTime,string &reason)
  {
   buySignal = false;
   sellSignal = false;
   barTime = 0;
   reason = "";

   if(!InpUseCrystalHeikinSignal)
      return true;

   if(g_crystalHandle == INVALID_HANDLE)
     {
      reason = "indicator handle not ready";
      return false;
     }

   const int signalShift = MathMax(1,shift);
   barTime = iTime(_Symbol,g_crystalTF,signalShift);

   double buyBuf[];
   double sellBuf[];
   ArrayResize(buyBuf,1);
   ArrayResize(sellBuf,1);

   if(CopyBuffer(g_crystalHandle,InpCrystalBuyBuffer,signalShift,1,buyBuf) <= 0)
     {
      reason = "buy buffer copy failed";
      return false;
     }
   if(CopyBuffer(g_crystalHandle,InpCrystalSellBuffer,signalShift,1,sellBuf) <= 0)
     {
      reason = "sell buffer copy failed";
      return false;
     }

   const double buyValue = buyBuf[0];
   const double sellValue = sellBuf[0];

   if(InpCrystalSignalUseNonEmpty)
     {
      buySignal = (MathIsValidNumber(buyValue) && buyValue != EMPTY_VALUE && buyValue != 0.0);
      sellSignal = (MathIsValidNumber(sellValue) && sellValue != EMPTY_VALUE && sellValue != 0.0);
     }
   else
     {
      buySignal = (MathIsValidNumber(buyValue) && buyValue > 0.0);
      sellSignal = (MathIsValidNumber(sellValue) && sellValue > 0.0);
     }

   if(!buySignal && !sellSignal && InpCrystalUseColorFallback)
     {
      double haOpen[];
      double haClose[];
      ArrayResize(haOpen,1);
      ArrayResize(haClose,1);

      if(CopyBuffer(g_crystalHandle,InpCrystalHAOpenBuffer,signalShift,1,haOpen) > 0 &&
         CopyBuffer(g_crystalHandle,InpCrystalHACloseBuffer,signalShift,1,haClose) > 0)
        {
         if(MathIsValidNumber(haOpen[0]) &&
            MathIsValidNumber(haClose[0]) &&
            haOpen[0] != EMPTY_VALUE &&
            haClose[0] != EMPTY_VALUE)
           {
            if(haClose[0] > haOpen[0])
               buySignal = true;
            else if(haClose[0] < haOpen[0])
               sellSignal = true;
           }
        }
     }

   if(InpCrystalInvertSignal)
     {
      const bool swap = buySignal;
      buySignal = sellSignal;
      sellSignal = swap;
     }

   if(buySignal && sellSignal)
     {
      reason = "ambiguous buy/sell signal";
      return false;
     }

   return true;
  }

bool ConfirmCrystalSignal(const bool bullish,string &reason,string &tagOut,datetime &signalBarTimeOut)
  {
   reason = "";
   tagOut = "";
   signalBarTimeOut = 0;

   if(!InpUseCrystalHeikinSignal)
      return true;

   const ENUM_TIMEFRAMES tfNow = ResolveCrystalSignalTF();
   if(g_crystalHandle == INVALID_HANDLE || g_crystalTF != tfNow)
     {
      if(!InitCrystalSignalEngine())
        {
         reason = "indicator init failed";
         return false;
        }
     }

   bool buySignal = false;
   bool sellSignal = false;
   datetime signalBarTime = 0;
   const int confirmCandles = IsMasterExecutionMode() ? 0 : MathMax(0,InpCrystalConfirmCandles);
   const int signalShift = MathMax(1,InpCrystalSignalShift + confirmCandles);
   if(Bars(_Symbol,g_crystalTF) < signalShift + 5)
     {
      reason = "waiting more candles for crystal confirmation";
      return false;
     }
   if(!ReadCrystalSignalFlags(signalShift,buySignal,sellSignal,signalBarTime,reason))
      return false;
   signalBarTimeOut = signalBarTime;

   if(bullish && !buySignal)
     {
      reason = "buy signal missing";
      return false;
     }

   if(!bullish && !sellSignal)
     {
      reason = "sell signal missing";
      return false;
     }

   if(InpUseKUTMilzCleanSetupOnly)
     {
      string cleanTag = "";
      if(!PassKUTMilzCleanSetup(bullish,signalShift,reason,cleanTag))
         return false;
      if(StringLen(cleanTag) > 0)
         tagOut = cleanTag;
     }

   if(InpCrystalOneSignalPerBar && signalBarTime > 0)
     {
      if(bullish)
        {
         if(g_lastCrystalBuyBar == signalBarTime)
           {
            reason = "buy signal already used on this bar";
            return false;
           }
        }
      else
        {
         if(g_lastCrystalSellBar == signalBarTime)
           {
            reason = "sell signal already used on this bar";
            return false;
           }
        }
     }

   const string baseTag = (bullish ? "CRYSTAL_BUY" : "CRYSTAL_SELL") + "_C" + IntegerToString(confirmCandles);
   tagOut = (StringLen(tagOut) > 0) ? (tagOut + "+" + baseTag) : baseTag;
   return true;
  }

bool IsBullishCandleAt(const int shift)
  {
   if(shift < 1)
      return false;
   const double o = iOpen(_Symbol,InpExecutionTF,shift);
   const double c = iClose(_Symbol,InpExecutionTF,shift);
   if(o <= 0.0 || c <= 0.0)
      return false;
   return (c > o);
  }

bool IsBearishCandleAt(const int shift)
  {
   if(shift < 1)
      return false;
   const double o = iOpen(_Symbol,InpExecutionTF,shift);
   const double c = iClose(_Symbol,InpExecutionTF,shift);
   if(o <= 0.0 || c <= 0.0)
      return false;
   return (c < o);
  }

int GetSwingLabelAtShift(const int shift,const int wing,const int lookback,double &priceOut)
  {
   priceOut = 0.0;
   const int w = MathMax(2,wing);
   const int lb = MathMax(40,lookback);
   const int bars = Bars(_Symbol,InpExecutionTF);
   if(shift <= w || shift + w >= bars)
      return SWING_NONE;

   const int maxScan = MathMin(bars - (w + 1),shift + lb);
   bool highAt = IsSwingHighAt(shift,w);
   bool lowAt = IsSwingLowAt(shift,w);
   if(!highAt && !lowAt)
      return SWING_NONE;

   if(highAt && lowAt)
     {
      const double upWick = iHigh(_Symbol,InpExecutionTF,shift) - MathMax(iOpen(_Symbol,InpExecutionTF,shift),iClose(_Symbol,InpExecutionTF,shift));
      const double dnWick = MathMin(iOpen(_Symbol,InpExecutionTF,shift),iClose(_Symbol,InpExecutionTF,shift)) - iLow(_Symbol,InpExecutionTF,shift);
      highAt = (upWick >= dnWick);
      lowAt = !highAt;
     }

   if(highAt)
     {
      priceOut = iHigh(_Symbol,InpExecutionTF,shift);
      for(int i = shift + 1; i <= maxScan; i++)
        {
         if(!IsSwingHighAt(i,w))
            continue;
         const double prevHigh = iHigh(_Symbol,InpExecutionTF,i);
         return (priceOut > prevHigh) ? SWING_HH : SWING_LH;
        }
      return SWING_NONE;
     }

   priceOut = iLow(_Symbol,InpExecutionTF,shift);
   for(int i = shift + 1; i <= maxScan; i++)
     {
      if(!IsSwingLowAt(i,w))
         continue;
      const double prevLow = iLow(_Symbol,InpExecutionTF,i);
      return (priceOut > prevLow) ? SWING_HL : SWING_LL;
     }
   return SWING_NONE;
  }

bool IsHigherHighAtShift(const int shift,const int wing,const int lookback,double &hhPriceOut)
  {
   hhPriceOut = 0.0;
   const int label = GetSwingLabelAtShift(shift,wing,lookback,hhPriceOut);
   return (label == SWING_HH);
  }

bool PassKUTMilzCleanSetup(const bool bullish,const int signalShift,string &reason,string &tagOut)
  {
   reason = "";
   tagOut = "";

   const int bars = Bars(_Symbol,InpExecutionTF);
   const int wing = MathMax(2,InpKUTMilzSwingWing);
   const int lookback = MathMax(60,InpKUTMilzSwingLookback);
   const int s0 = signalShift;
   const int s1 = signalShift + 1;
   const int s2 = signalShift + 2;
   const int s3 = signalShift + 3;
   const int s4 = signalShift + 4;

   if(bars < s4 + wing + 5)
     {
      reason = "waiting bars for KUTMilz setup";
      return false;
     }

   if(IsCrash900ProfileActive())
     {
      if(!bullish)
        {
         reason = "crash900 is buy-only";
         return false;
        }

      // Crash900 buy real setup:
      // signal candle (0) bullish, candle -1 bullish, candles -2/-3 bearish, candle -4 bearish.
      // If sequence is not complete, treat as wait/fake and do not trade.
      if(!IsBullishCandleAt(s0))
        {
         reason = "crash900 buy setup: signal candle must be bullish";
         return false;
        }
      if(!IsBullishCandleAt(s1))
        {
         reason = "crash900 buy setup: candle-1 must be bullish";
         return false;
        }
      if(!IsBearishCandleAt(s2) || !IsBearishCandleAt(s3))
        {
         reason = "crash900 buy setup: candles-2 and -3 must be bearish";
         return false;
        }
      if(!IsBearishCandleAt(s4))
        {
         reason = "crash900 buy setup: candle-4 must be bearish";
         return false;
        }

      tagOut = "CRASH900_BUY_REAL";
      return true;
     }

   if(!bullish)
     {
      // SELL fake: candle -1 is colored and a HL/LH appears at -2 or -3.
      double fakePx2 = 0.0;
      double fakePx3 = 0.0;
      const int fakeLbl2 = GetSwingLabelAtShift(s2,wing,lookback,fakePx2);
      const int fakeLbl3 = GetSwingLabelAtShift(s3,wing,lookback,fakePx3);
      const bool c1Colored = (IsBullishCandleAt(s1) || IsBearishCandleAt(s1));
      const bool hasFakeStruct = (fakeLbl2 == SWING_HL || fakeLbl2 == SWING_LH ||
                                  fakeLbl3 == SWING_HL || fakeLbl3 == SWING_LH);
      if(c1Colored && hasFakeStruct)
        {
         reason = "sell fake pattern blocked";
         return false;
        }

      // SELL real: HH locked at -4, post-HH candle (-3) must not break HH,
      // then trigger candle (0) closes bearish.
      double hhPrice = 0.0;
      if(!IsHigherHighAtShift(s4,wing,lookback,hhPrice))
        {
         reason = "sell setup: HH not formed";
         return false;
        }

      if(!(IsBullishCandleAt(s3) || IsBearishCandleAt(s3)))
        {
         reason = "sell setup: post-HH candle must be colored";
         return false;
        }

      if(iHigh(_Symbol,InpExecutionTF,s3) > hhPrice)
        {
         reason = "sell setup: post-HH candle broke HH";
         return false;
        }

      if(iHigh(_Symbol,InpExecutionTF,s2) > hhPrice ||
         iHigh(_Symbol,InpExecutionTF,s1) > hhPrice ||
         iHigh(_Symbol,InpExecutionTF,s0) > hhPrice)
        {
         reason = "sell setup: HH was broken by follow candles";
         return false;
        }

      if(!IsBearishCandleAt(s0))
        {
         reason = "sell setup: trigger candle not bearish";
         return false;
        }

      tagOut = "KUT_SELL_REAL";
      return true;
     }

   // BUY fake: -1 and -2 are both bullish, but -3 does not form HL/LL/LH.
   if(IsBullishCandleAt(s1) && IsBullishCandleAt(s2))
     {
      double fakePx = 0.0;
      const int fakeLbl = GetSwingLabelAtShift(s3,wing,lookback,fakePx);
      if(!(fakeLbl == SWING_HL || fakeLbl == SWING_LL || fakeLbl == SWING_LH))
        {
         reason = "buy fake pattern blocked";
         return false;
        }
     }

   if(!IsBullishCandleAt(s1))
     {
      reason = "buy setup: candle-1 must be green/blue";
      return false;
     }

   if(!IsBearishCandleAt(s2) || !IsBearishCandleAt(s3))
     {
      reason = "buy setup: candles -2 and -3 must be orange/red";
      return false;
     }

   double structPrice = 0.0;
   const int structLbl = GetSwingLabelAtShift(s3,wing,lookback,structPrice);
   if(!(structLbl == SWING_HL || structLbl == SWING_LL || structLbl == SWING_LH))
     {
      reason = "buy setup: candle-3 must form HL/LL/LH";
      return false;
     }

   const double cAfter = iClose(_Symbol,InpExecutionTF,s2);
   if(structLbl == SWING_LH)
     {
      if(cAfter > structPrice)
        {
         reason = "buy setup: post-structure candle broke LH";
         return false;
        }
     }
   else
     {
      if(cAfter < structPrice)
        {
         reason = "buy setup: post-structure candle broke HL/LL";
         return false;
        }
     }

   tagOut = "KUT_BUY_REAL";
   return true;
  }

bool ExecuteImmediateSignalOrder(FVGZone &zone,const datetime signalBarTime,const string signalTag)
  {
   string reason = "";
   const int regime = GetCurrentMarketRegime();
   const string setupTag = BuildSetupTag(zone,signalTag,regime);

   double requestedLots = InpFixedLots;
   requestedLots *= GetRegimeLotMultiplier();
   const double fallbackVolume = NormalizeVolume(requestedLots);
   if(fallbackVolume <= 0.0)
      return false;

   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetDeviationInPoints(MathMax(0,GetEffectiveSlippagePoints()));

   MqlTick tick;
   if(!GetFreshTick(tick,reason))
     {
      PrintFormat("ForceX KUTMilz order blocked (%s): %s",zone.name,reason);
      return false;
     }

   const int attempts = MathMax(1,GetEffectiveOrderRetries());
   for(int a = 0; a < attempts; a++)
     {
      reason = "";
      if(!GetFreshTick(tick,reason))
        {
         if(a < attempts - 1 && InpRetryDelayMs > 0)
            Sleep(InpRetryDelayMs);
         continue;
        }

      double sl = 0.0;
      double tp = 0.0;
      if(!BuildOrderLevels(zone.bullish,zone,tick,sl,tp,reason))
        {
         if(!BuildEmergencyLevelsFromMarket(zone.bullish,tick,sl,tp))
           {
            PrintFormat("ForceX KUTMilz order blocked (%s): %s",zone.name,reason);
            return false;
           }
        }

      const double volume = ComputeRiskSizedVolume(zone.bullish,tick,sl,fallbackVolume);
      if(volume <= 0.0)
        {
         PrintFormat("ForceX KUTMilz order blocked (%s): volume sizing failed",zone.name);
         return false;
        }

      const bool sent = zone.bullish ?
                        g_trade.Buy(volume,_Symbol,0.0,sl,tp,zone.name) :
                        g_trade.Sell(volume,_Symbol,0.0,sl,tp,zone.name);

      if(sent)
        {
         if(InpCrystalOneSignalPerBar && signalBarTime > 0)
           {
            if(zone.bullish)
               g_lastCrystalBuyBar = signalBarTime;
            else
               g_lastCrystalSellBar = signalBarTime;
           }
         g_signalEngine.TryTransition(FLOW_EXECUTED,CurrentExecBarIndex(),"KUTMilz immediate order sent");
         g_signalEngine.TryTransition(FLOW_MANAGING,CurrentExecBarIndex(),"KUTMilz immediate managing");
         zone.flowState = FLOW_MANAGEMENT_STATE;
         g_tradesToday++;
         if(InpUseSetupTagEngine)
           {
            if(AttachResultDealToTag(setupTag))
               QueueTagEvent("Entry accepted (KUTMILZ_IMMEDIATE): " + setupTag);
            else
               QueueTagEvent("Entry accepted (KUTMILZ_IMMEDIATE) but tag link missing: " + setupTag);
           }
         return true;
        }

      int rc = (int)g_trade.ResultRetcode();
      if(InpUseInvalidStopsRescue && IsInvalidStopsRetcode(rc))
        {
         const bool rescueSent = zone.bullish ?
                                 g_trade.Buy(volume,_Symbol,0.0,0.0,0.0,zone.name + "_RS") :
                                 g_trade.Sell(volume,_Symbol,0.0,0.0,0.0,zone.name + "_RS");
         if(rescueSent)
           {
            if(InpCrystalOneSignalPerBar && signalBarTime > 0)
              {
               if(zone.bullish)
                  g_lastCrystalBuyBar = signalBarTime;
               else
                  g_lastCrystalSellBar = signalBarTime;
              }
            g_signalEngine.TryTransition(FLOW_EXECUTED,CurrentExecBarIndex(),"KUTMilz rescue order sent");
            g_signalEngine.TryTransition(FLOW_MANAGING,CurrentExecBarIndex(),"KUTMilz rescue managing");
            zone.flowState = FLOW_MANAGEMENT_STATE;
            g_tradesToday++;
            string attachReason = "";
            if(!AttachProtectiveStopsAfterEntry(zone.bullish,zone,attachReason))
               PrintFormat("ForceX KUTMilz rescue opened without SL/TP attach (%s): %s",zone.name,attachReason);
            return true;
           }

         rc = (int)g_trade.ResultRetcode();
        }

      if(a < attempts - 1 && (IsRetryRetcode(rc) || IsInvalidStopsRetcode(rc)))
        {
         if(InpRetryDelayMs > 0)
            Sleep(InpRetryDelayMs);
         continue;
        }

      PrintFormat("ForceX KUTMilz order failed (%s): retcode=%d, comment=%s",
                  zone.name,rc,g_trade.ResultRetcodeDescription());
      return false;
     }

   PrintFormat("ForceX KUTMilz order failed (%s): market retries exhausted",zone.name);
   return false;
  }

bool IsMasterExecutionMode()
  {
   return (InpUseCrystalHeikinSignal && InpUseKUTMilzCleanSetupOnly && InpKUTMilzMasterExecutionOverride);
  }

bool HasOpenMagicPositionDirection(const bool bullish)
  {
   const long wantType = bullish ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      if(PositionGetInteger(POSITION_TYPE) == wantType)
         return true;
     }
   return false;
  }

bool CloseOppositeMagicPositionsForMaster(const bool bullish)
  {
   const long oppositeType = bullish ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
   const double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   const int barSeconds = MathMax(1,PeriodSeconds(InpExecutionTF));
   bool closedAny = false;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;

      const long pType = PositionGetInteger(POSITION_TYPE);
      if(pType != oppositeType)
         continue;

      const double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      const double profitUsd = PositionGetDouble(POSITION_PROFIT);
      const datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
      const int ageBars = (posTime > 0) ? (int)((TimeCurrent() - posTime) / barSeconds) : 0;
      const double profitPts = (pType == POSITION_TYPE_BUY) ?
                               ((bid - openPrice) / _Point) :
                               ((openPrice - ask) / _Point);

      if(CloseMagicPositionWithReason(ticket,
                                      "master override opposite close",
                                      profitPts,
                                      profitUsd,
                                      ageBars))
         closedAny = true;
     }

   return closedAny;
  }

bool TryMasterExecutionEntryOnBarClose()
  {
   if(!IsMasterExecutionMode())
      return false;

   const datetime closedBarTime = iTime(_Symbol,InpExecutionTF,1);
   if(closedBarTime <= 0)
      return false;
   if(closedBarTime == g_lastMasterSignalEvalBar)
      return false;
   g_lastMasterSignalEvalBar = closedBarTime;

   string buyReason = "";
   string buyTag = "";
   datetime buySignalBar = 0;
   const bool buyReady = ConfirmCrystalSignal(true,buyReason,buyTag,buySignalBar);

   string sellReason = "";
   string sellTag = "";
   datetime sellSignalBar = 0;
   const bool sellReady = ConfirmCrystalSignal(false,sellReason,sellTag,sellSignalBar);

   if(buyReady && sellReady)
     {
      if(InpTriggerDecisionLogs || InpDebugMode)
         Print("ForceX master override blocked: ambiguous buy/sell confirmation");
      return false;
     }

   if(!buyReady && !sellReady)
     {
      if(InpTriggerDecisionLogs || InpDebugMode)
         PrintFormat("ForceX master wait: buy=%s | sell=%s",
                     StringLen(buyReason) > 0 ? buyReason : "-",
                     StringLen(sellReason) > 0 ? sellReason : "-");
      return false;
     }

   const bool bullish = buyReady;
   const datetime signalBarTime = bullish ? buySignalBar : sellSignalBar;
   const string signalTag = bullish ? buyTag : sellTag;

   CloseOppositeMagicPositionsForMaster(bullish);

   MqlTick tick;
   string tickReason = "";
   if(!GetFreshTick(tick,tickReason))
     {
      if(InpTriggerDecisionLogs || InpDebugMode)
         PrintFormat("ForceX master blocked: %s",tickReason);
      return false;
     }

   FVGZone zone;
   zone.name = StringFormat("FX_MASTER_%s_%I64d",bullish ? "BUY" : "SELL",(long)closedBarTime);
   zone.bullish = bullish;
   zone.time1 = closedBarTime;
   zone.time2 = closedBarTime + (datetime)(MathMax(4,InpFVGRectBars) * MathMax(1,PeriodSeconds(InpExecutionTF)));
   zone.active = true;
   zone.flowState = FLOW_ENTRY_READY;
   zone.confidence = 100.0;

   double low1 = iLow(_Symbol,InpExecutionTF,1);
   double high1 = iHigh(_Symbol,InpExecutionTF,1);
   if(low1 <= 0.0 || high1 <= 0.0 || high1 <= low1)
     {
      const double center = bullish ? tick.ask : tick.bid;
      low1 = center - (10.0 * _Point);
      high1 = center + (10.0 * _Point);
     }
   zone.lower = MathMin(low1,high1);
   zone.upper = MathMax(low1,high1);
   zone.sweepWick = bullish ? zone.lower : zone.upper;
   zone.targetLiquidity = bullish ? (tick.ask + 30.0 * _Point) : (tick.bid - 30.0 * _Point);

   const string execTag = (StringLen(signalTag) > 0) ? ("MASTER+" + signalTag) : "MASTER";
   const bool opened = ExecuteImmediateSignalOrder(zone,signalBarTime,execTag);
   if(opened)
      PrintFormat("ForceX master execution fired: %s (%s)",bullish ? "BUY" : "SELL",execTag);

   return opened;
  }

void DetectSymbolProfile()
  {
   string sym = _Symbol;
   StringToLower(sym);

   g_isV75 = (StringFind(sym,"volatility 75") >= 0 ||
              StringFind(sym,"volatilityb 75") >= 0 ||
              StringFind(sym,"v75") >= 0);
   g_isV751s = (g_isV75 && StringFind(sym,"1s") >= 0);
   g_isCrash900 = (StringFind(sym,"crash 900") >= 0 ||
                   StringFind(sym,"crash900") >= 0);
  }

bool IsV75ProfileActive()
  {
   return (InpEnableV75Profile && g_isV75);
  }

bool IsCrash900ProfileActive()
  {
   return (InpEnableCrash900Profile && g_isCrash900);
  }

void ResolveModeProfile()
  {
   g_modeStrongActive = false;
   g_modeScalpActive = false;
   g_modeProfile = "BASE";

   if(InpSimpleModeNoGates)
     {
      g_modeProfile = "SIMPLE";
      return;
     }

   if(InpStrongMode && InpScalpMode)
     {
      // Single active mode enforcement: when both are enabled, prefer Strong mode.
      g_modeStrongActive = true;
      g_modeScalpActive = false;
      g_modeProfile = "STRONG";
      Print("ForceX mode conflict detected (Strong+Scalp). Enforcing single active mode: STRONG");
      return;
     }

   if(InpStrongMode)
     {
      g_modeStrongActive = true;
      g_modeProfile = "STRONG";
      return;
     }

   if(InpScalpMode)
     {
      g_modeScalpActive = true;
      g_modeProfile = "SCALP";
      return;
     }
  }

bool IsStrongModeActive()
  {
   return g_modeStrongActive;
  }

bool IsScalpModeActive()
  {
   return g_modeScalpActive;
  }

int GetAdaptiveLookbackBarsEff()
  {
   if(IsV75ProfileActive())
      return g_isV751s ? MathMax(120,MathMin(900,InpAdaptiveLookbackBarsV751s))
                       : MathMax(120,MathMin(900,InpAdaptiveLookbackBarsV75));
   return MathMax(120,MathMin(900,InpAdaptiveLookbackBars));
  }

double GetAdaptiveStrongScoreEff()
  {
   if(IsV75ProfileActive())
      return g_isV751s ? InpAdaptiveStrongScoreV751s : InpAdaptiveStrongScoreV75;
   return InpAdaptiveStrongScore;
  }

double GetAdaptiveWeakScoreEff()
  {
   if(IsV75ProfileActive())
      return g_isV751s ? InpAdaptiveWeakScoreV751s : InpAdaptiveWeakScoreV75;
   return InpAdaptiveWeakScore;
  }

int GetAdaptiveMaxHitsShiftEff()
  {
   if(IsV75ProfileActive())
      return g_isV751s ? MathMax(0,InpAdaptiveMaxHitsShiftV751s) : MathMax(0,InpAdaptiveMaxHitsShiftV75);
   return MathMax(0,InpAdaptiveMaxHitsShift);
  }

double GetAdaptiveToleranceShiftPctEff()
  {
   if(IsV75ProfileActive())
      return g_isV751s ? MathMax(0.0,InpAdaptiveToleranceShiftPctV751s) : MathMax(0.0,InpAdaptiveToleranceShiftPctV75);
   return MathMax(0.0,InpAdaptiveToleranceShiftPct);
  }

int GetAdaptiveTickDelayShiftEff()
  {
   if(IsV75ProfileActive())
      return g_isV751s ? MathMax(0,InpAdaptiveTickDelayShiftV751s) : MathMax(0,InpAdaptiveTickDelayShiftV75);
   return MathMax(0,InpAdaptiveTickDelayShift);
  }

void RefreshAdaptiveTriggerModel()
  {
   if(!InpUseAdaptiveTriggerModel)
     {
      g_adaptModelBullScore = 50.0;
      g_adaptModelBearScore = 50.0;
      g_adaptModelTolMultBull = 1.0;
      g_adaptModelTolMultBear = 1.0;
      g_adaptModelHitsShiftBull = 0;
      g_adaptModelHitsShiftBear = 0;
      g_adaptModelTickDelayAdd = 0;
      g_adaptModelStateTag = "OFF";
      return;
     }

   const datetime barTime = iTime(_Symbol,InpExecutionTF,0);
   if(barTime > 0 && barTime == g_lastAdaptiveModelBar)
      return;
   g_lastAdaptiveModelBar = barTime;

   const int bars = Bars(_Symbol,InpExecutionTF);
   int lookback = GetAdaptiveLookbackBarsEff();
   lookback = MathMin(lookback,bars - 3);
   if(lookback < 40)
     {
      g_adaptModelBullScore = 50.0;
      g_adaptModelBearScore = 50.0;
      g_adaptModelTolMultBull = 1.0;
      g_adaptModelTolMultBear = 1.0;
      g_adaptModelHitsShiftBull = 0;
      g_adaptModelHitsShiftBear = 0;
      g_adaptModelTickDelayAdd = 0;
      g_adaptModelStateTag = "LOW_DATA";
      return;
     }

   int upCount = 0;
   int dnCount = 0;
   int bullStruct = 0;
   int bearStruct = 0;
   double rangeSum = 0.0;
   double bodySum = 0.0;
   double bullBody = 0.0;
   double bearBody = 0.0;

   for(int i = 1; i <= lookback; i++)
     {
      const double o0 = iOpen(_Symbol,InpExecutionTF,i);
      const double c0 = iClose(_Symbol,InpExecutionTF,i);
      const double h0 = iHigh(_Symbol,InpExecutionTF,i);
      const double l0 = iLow(_Symbol,InpExecutionTF,i);
      const double h1 = iHigh(_Symbol,InpExecutionTF,i+1);
      const double l1 = iLow(_Symbol,InpExecutionTF,i+1);

      if(c0 > o0)
         upCount++;
      else if(c0 < o0)
         dnCount++;

      if(h0 > h1 && l0 > l1)
         bullStruct++;
      if(h0 < h1 && l0 < l1)
         bearStruct++;

      const double body = MathAbs(c0 - o0);
      bodySum += body;
      if(c0 > o0)
         bullBody += (c0 - o0);
      else if(c0 < o0)
         bearBody += (o0 - c0);

      rangeSum += MathMax(h0 - l0,_Point);
     }

   const double dirBull = 100.0 * ((double)upCount / (double)lookback);
   const double dirBear = 100.0 * ((double)dnCount / (double)lookback);
   const double structBull = 100.0 * ((double)bullStruct / (double)lookback);
   const double structBear = 100.0 * ((double)bearStruct / (double)lookback);
   const double momBull = (bodySum > 0.0) ? (100.0 * bullBody / bodySum) : 50.0;
   const double momBear = (bodySum > 0.0) ? (100.0 * bearBody / bodySum) : 50.0;

   const double avgRange = rangeSum / lookback;
   const double recentRange = MathMax(iHigh(_Symbol,InpExecutionTF,1) - iLow(_Symbol,InpExecutionTF,1),_Point);
   const double volRatio = recentRange / MathMax(avgRange,_Point);
   const double volFit = MathMax(0.0,100.0 - MathMin(100.0,MathAbs(volRatio - 1.10) * 70.0));

   g_adaptModelBullScore = MathMax(0.0,MathMin(100.0,dirBull * 0.30 + structBull * 0.35 + momBull * 0.20 + volFit * 0.15));
   g_adaptModelBearScore = MathMax(0.0,MathMin(100.0,dirBear * 0.30 + structBear * 0.35 + momBear * 0.20 + volFit * 0.15));

   const int maxShift = GetAdaptiveMaxHitsShiftEff();
   const double tolStep = GetAdaptiveToleranceShiftPctEff() / 100.0;
   const double strongScore = MathMax(0.0,MathMin(100.0,GetAdaptiveStrongScoreEff()));
   const double weakScore = MathMax(0.0,MathMin(strongScore,GetAdaptiveWeakScoreEff()));

   g_adaptModelHitsShiftBull = 0;
   g_adaptModelHitsShiftBear = 0;
   g_adaptModelTolMultBull = 1.0;
   g_adaptModelTolMultBear = 1.0;

   if(g_adaptModelBullScore >= strongScore)
     {
      g_adaptModelHitsShiftBull = -maxShift;
      g_adaptModelTolMultBull = 1.0 + tolStep;
     }
   else if(g_adaptModelBullScore <= weakScore)
     {
      g_adaptModelHitsShiftBull = maxShift;
      g_adaptModelTolMultBull = MathMax(0.25,1.0 - tolStep);
     }

   if(g_adaptModelBearScore >= strongScore)
     {
      g_adaptModelHitsShiftBear = -maxShift;
      g_adaptModelTolMultBear = 1.0 + tolStep;
     }
   else if(g_adaptModelBearScore <= weakScore)
     {
      g_adaptModelHitsShiftBear = maxShift;
      g_adaptModelTolMultBear = MathMax(0.25,1.0 - tolStep);
     }

   const int tickShift = GetAdaptiveTickDelayShiftEff();
   g_adaptModelTickDelayAdd = 0;
   if(g_adaptModelBullScore > g_adaptModelBearScore)
     {
      if(g_adaptModelBullScore >= strongScore)
         g_adaptModelTickDelayAdd = -tickShift;
      else if(g_adaptModelBullScore <= weakScore)
         g_adaptModelTickDelayAdd = tickShift;
      g_adaptModelStateTag = "BULL";
     }
   else if(g_adaptModelBearScore > g_adaptModelBullScore)
     {
      if(g_adaptModelBearScore >= strongScore)
         g_adaptModelTickDelayAdd = -tickShift;
      else if(g_adaptModelBearScore <= weakScore)
         g_adaptModelTickDelayAdd = tickShift;
      g_adaptModelStateTag = "BEAR";
     }
   else
     {
      g_adaptModelStateTag = "NEUTRAL";
     }

   if(InpAdaptiveModelLogs)
      PrintFormat("ForceX AdaptiveModel: lookback=%d bull=%.1f bear=%.1f hits(B/S)=%d/%d tol(B/S)=%.2f/%.2f tickAdd=%d state=%s",
                  lookback,
                  g_adaptModelBullScore,
                  g_adaptModelBearScore,
                  g_adaptModelHitsShiftBull,
                  g_adaptModelHitsShiftBear,
                  g_adaptModelTolMultBull,
                  g_adaptModelTolMultBear,
                  g_adaptModelTickDelayAdd,
                  g_adaptModelStateTag);
  }

int GetAdaptiveRequiredHitsShift(const bool bullish)
  {
   if(!InpUseAdaptiveTriggerModel)
      return 0;
   return bullish ? g_adaptModelHitsShiftBull : g_adaptModelHitsShiftBear;
  }

double GetAdaptiveToleranceMultiplier(const bool bullish)
  {
   if(!InpUseAdaptiveTriggerModel)
      return 1.0;
   return bullish ? g_adaptModelTolMultBull : g_adaptModelTolMultBear;
  }

string GetAdaptiveStateTag(const bool bullish)
  {
   if(!InpUseAdaptiveTriggerModel)
      return "ADP_OFF";
   const double score = bullish ? g_adaptModelBullScore : g_adaptModelBearScore;
   const string side = bullish ? "B" : "S";
   return "ADP_" + side + IntegerToString((int)MathRound(score));
  }

bool IsManualSLTPProtectedPosition()
  {
   if(!InpProtectManualSLTPTrades)
      return false;

   string tag = InpManualTradeCommentTag;
   if(StringLen(tag) > 0)
     {
      string comment = PositionGetString(POSITION_COMMENT);
      StringToLower(comment);
      StringToLower(tag);
      if(StringFind(comment,tag) < 0)
         return false;
     }

   if(InpManualProtectByCommentOnly)
      return true;

   const double sl = PositionGetDouble(POSITION_SL);
   const double tp = PositionGetDouble(POSITION_TP);
   if(InpManualProtectRequireBothSLTP)
      return (sl > 0.0 && tp > 0.0);
   return (sl > 0.0 || tp > 0.0);
  }

bool HasProtectedManualPositionOpen()
  {
   if(!InpProtectManualSLTPTrades)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      if(g_signalEngine.State() == FLOW_EXECUTED || g_signalEngine.State() == FLOW_MANAGING)
         g_signalEngine.TryTransition(FLOW_MANAGING,CurrentExecBarIndex(),"position management tick");
      if(IsManualSLTPProtectedPosition())
         return true;
     }
   return false;
  }

int GetEffectiveMinGapPoints()
  {
   if(!IsV75ProfileActive())
      return InpMinGapPoints;

   return g_isV751s ? InpV751sMinGapPoints : InpV75MinGapPoints;
  }

int GetEffectiveInvalidationPoints()
  {
   if(!IsV75ProfileActive())
      return InpInvalidationPoints;

   return g_isV751s ? InpV751sInvalidationPoints : InpV75InvalidationPoints;
  }

int GetEffectiveMaxSpreadPoints()
  {
   if(!IsV75ProfileActive())
      return InpMaxSpreadPoints;

   return g_isV751s ? InpV751sMaxSpreadPoints : InpV75MaxSpreadPoints;
  }

int GetEffectiveSlippagePoints()
  {
   if(!IsV75ProfileActive())
      return InpSlippagePoints;

   return g_isV751s ? InpV751sSlippagePoints : InpV75SlippagePoints;
  }

int GetEffectiveOrderRetries()
  {
   if(!IsV75ProfileActive())
      return InpOrderRetries;

   return g_isV751s ? InpV751sOrderRetries : InpV75OrderRetries;
  }

int GetEffectiveMaxTradesPerDay()
  {
   if(!IsV75ProfileActive())
      return InpMaxTradesPerDay;

   return g_isV751s ? InpV751sMaxTradesPerDay : InpV75MaxTradesPerDay;
  }

int GetEffectiveMinStopDistancePoints()
  {
   if(!IsV75ProfileActive())
      return 0;

   return g_isV751s ? InpV751sMinStopDistancePts : InpV75MinStopDistancePts;
  }

double GetEffectiveRiskReward()
  {
   return IsScalpModeActive() ? InpScalpRiskReward : InpRiskReward;
  }

int GetEffectiveSLBufferPoints()
  {
   return IsScalpModeActive() ? InpScalpSLBufferPoints : InpSLBufferPoints;
  }

int GetEffectiveMinTriggerHits()
  {
   if(!IsScalpModeActive())
      return MathMax(1,InpMinTriggerHits);

   return MathMax(1,MathMax(InpMinTriggerHits,InpScalpMinTriggerHits));
  }

double GetEffectiveMinAIScore()
  {
   double score = InpMinAIScore;
   if(IsStrongModeActive())
      score = MathMax(score,(double)InpStrongMinAIScore);
   if(IsScalpModeActive())
      score = MathMax(score,(double)InpScalpMinAIScore);
   return score;
  }

int GetEffectiveBreakEvenTriggerPoints()
  {
   return IsScalpModeActive() ? InpScalpBreakEvenTriggerPoints : InpBreakEvenTriggerPoints;
  }

int GetEffectiveBreakEvenOffsetPoints()
  {
   return IsScalpModeActive() ? InpScalpBreakEvenOffsetPoints : InpBreakEvenOffsetPoints;
  }

bool GetEffectiveUseTrailingStop()
  {
   return IsScalpModeActive() ? InpScalpUseTrailingStop : InpUseTrailingStop;
  }

int GetEffectiveTrailingStartPoints()
  {
   return IsScalpModeActive() ? InpScalpTrailingStartPoints : InpTrailingStartPoints;
  }

int GetEffectiveTrailingDistancePoints()
  {
   return IsScalpModeActive() ? InpScalpTrailingDistancePoints : InpTrailingDistancePoints;
  }

int GetEffectiveMaxPositionBars()
  {
   return IsScalpModeActive() ? MathMax(0,InpScalpMaxPositionBars) : 0;
  }

double GetAdaptiveExecutionMinConfidence()
  {
   RefreshDynamicConfidenceOffset();
   const double v = InpExecutionMinConfidence + g_adaptConfidenceAdd + g_dynamicConfOffset + GetRegimeConfidenceOffset();
   return MathMin(100.0,MathMax(0.0,v));
  }

int GetAdaptiveTriggerBufferPoints()
  {
   return MathMax(0,InpTriggerBufferPoints + g_adaptTriggerBufAdd);
  }

int GetAdaptiveTriggerTickDelay()
  {
   return MathMax(0,InpTriggerTickDelay + g_adaptTickDelayAdd + g_adaptModelTickDelayAdd);
  }

double GetAdaptiveViolenceMultiplier()
  {
   return MathMax(1.0,InpV75ViolenceMultiplier + g_adaptViolenceAdd);
  }

int GetAdaptiveSweepSLExtraPoints()
  {
   return MathMax(1,InpV75SweepSLExtraPoints + g_adaptSweepSLAdd);
  }

void SetEntryScoreContext(const FVGZone &zone,
                          const double patternScore,
                          const double aiScore,
                          const int regime,
                          const bool instReady,
                          const bool phase2Pass,
                          const bool phase4Pass,
                          const bool accelPass,
                          const double setupTagScore,
                          const bool setupTagBlocked)
  {
   g_entryScoreCtxZone = zone;
   g_entryScoreCtxPattern = patternScore;
   g_entryScoreCtxAIScore = aiScore;
   g_entryScoreCtxRegime = regime;
   g_entryScoreCtxInstReady = instReady;
   g_entryScoreCtxPhase2Pass = phase2Pass;
   g_entryScoreCtxPhase4Pass = phase4Pass;
   g_entryScoreCtxAccelPass = accelPass;
   g_entryScoreCtxSetupTagScore = setupTagScore;
   g_entryScoreCtxSetupTagBlocked = setupTagBlocked;
   g_entryScoreCtxReady = true;
  }

double GetDynamicConfidenceScoreOffset()
  {
   RefreshDynamicConfidenceOffset();
   const double raw = -g_dynamicConfOffset / 6.0;
   return MathMax(-2.0,MathMin(2.0,raw));
  }

int GetAdaptiveConfirmThreshold(const int baseThreshold)
  {
   const int base = MathMax(1,baseThreshold);
   if(!InpUseAdaptiveConfirmThreshold)
      return base;

   const datetime now = TimeCurrent();
   const datetime from = now - (datetime)(45 * 24 * 60 * 60);
   bool allLoss = true;
   int sampled = 0;

   if(HistorySelect(from,now))
     {
      for(int i = HistoryDealsTotal() - 1; i >= 0 && sampled < 3; i--)
        {
         const ulong deal = HistoryDealGetTicket(i);
         if(deal == 0)
            continue;
         if((long)HistoryDealGetInteger(deal,DEAL_MAGIC) != InpMagic)
            continue;
         if(HistoryDealGetString(deal,DEAL_SYMBOL) != _Symbol)
            continue;
         if((long)HistoryDealGetInteger(deal,DEAL_ENTRY) != DEAL_ENTRY_OUT)
            continue;

         const double pnl = HistoryDealGetDouble(deal,DEAL_PROFIT) +
                            HistoryDealGetDouble(deal,DEAL_SWAP) +
                            HistoryDealGetDouble(deal,DEAL_COMMISSION);
         if(pnl > 0.0)
            allLoss = false;
         sampled++;
        }
     }

   int out = base;
   if((sampled >= 3 && allLoss) || g_lossStreak >= 3)
      out++;
   return MathMax(base,out);
  }

double ComputeSetupTagScore(const string tag)
  {
   if(!InpUseSetupTagEngine || StringLen(tag) == 0)
      return 0.0;

   const int idx = FindTagStatIndex(tag,false);
   if(idx < 0)
      return 0.8;

   const int samples = MathMax(0,g_tagStats[idx].closedSamples);
   const int wins = MathMax(0,g_tagStats[idx].wins);
   const int losses = MathMax(0,g_tagStats[idx].losses);
   const int total = MathMax(1,samples > 0 ? samples : (wins + losses));
   const double wr = (double)wins / (double)total;
   double score = 1.0;

   if(wr >= 0.65)
      score = 2.0;
   else if(wr >= 0.55)
      score = 1.6;
   else if(wr >= 0.45)
      score = 1.2;
   else if(wr >= 0.35)
      score = 0.8;
   else
      score = 0.4;

   if(g_tagStats[idx].pausedUntil > TimeCurrent())
      score = MathMin(score,0.2);

   return MathMax(0.0,MathMin(2.0,score));
  }

bool PassAccelerationFilter(const bool bullish,double &bodyPct,double &volRatio,double &dispRatio)
  {
   bodyPct = 0.0;
   volRatio = 1.0;
   dispRatio = 1.0;

   if(!InpUseEntryAccelerationFilter)
      return true;

   const int bars = Bars(_Symbol,InpExecutionTF);
   if(bars < 12)
      return false;

   const double o1 = iOpen(_Symbol,InpExecutionTF,1);
   const double c1 = iClose(_Symbol,InpExecutionTF,1);
   const double h1 = iHigh(_Symbol,InpExecutionTF,1);
   const double l1 = iLow(_Symbol,InpExecutionTF,1);
   const double range1 = MathMax(h1 - l1,_Point);
   bodyPct = 100.0 * (MathAbs(c1 - o1) / range1);
   const bool dirBody = bullish ? (c1 > o1) : (c1 < o1);

   double volSum = 0.0;
   double rangeSum = 0.0;
   int used = 0;
   for(int i = 2; i <= 6; i++)
     {
      volSum += (double)iVolume(_Symbol,InpExecutionTF,i);
      rangeSum += MathMax(iHigh(_Symbol,InpExecutionTF,i) - iLow(_Symbol,InpExecutionTF,i),_Point);
      used++;
     }
   const double avgVol = (used > 0) ? (volSum / used) : 0.0;
   const double avgRange = (used > 0) ? (rangeSum / used) : _Point;
   const double v1 = (double)iVolume(_Symbol,InpExecutionTF,1);
   volRatio = (avgVol > 0.0) ? (v1 / avgVol) : 1.0;
   dispRatio = range1 / MathMax(avgRange,_Point);

   return (dirBody &&
           bodyPct >= MathMax(1.0,InpAccelBodyPctMin) &&
           volRatio >= MathMax(0.1,InpAccelVolumeRatioMin) &&
           dispRatio >= MathMax(0.1,InpAccelDisplacementRatioMin));
  }

void GetScoreProfileFactors(double &trendMul,double &liqMul,double &instMul,double &fvgMul,double &phaseMul,double &accelPenaltyMul)
  {
   const bool v751s = g_isV751s;
   trendMul = v751s ? InpScoreTrendMulV751s : InpScoreTrendMulV75;
   liqMul = v751s ? InpScoreLiquidityMulV751s : InpScoreLiquidityMulV75;
   instMul = v751s ? InpScoreInstitutionalMulV751s : InpScoreInstitutionalMulV75;
   fvgMul = v751s ? InpScoreFvgMulV751s : InpScoreFvgMulV75;
   phaseMul = v751s ? InpScorePhaseMulV751s : InpScorePhaseMulV75;
   accelPenaltyMul = v751s ? InpScoreAccelPenaltyV751s : InpScoreAccelPenaltyV75;

   if(IsStrongModeActive())
     {
      trendMul += 0.10;
      instMul += 0.10;
      liqMul = MathMax(0.5,liqMul - 0.05);
     }
   if(IsScalpModeActive())
     {
      liqMul += 0.10;
      fvgMul += 0.10;
      phaseMul += 0.05;
      accelPenaltyMul += 0.10;
      trendMul = MathMax(0.5,trendMul - 0.05);
     }

   trendMul = MathMax(0.50,MathMin(1.80,trendMul));
   liqMul = MathMax(0.50,MathMin(1.80,liqMul));
   instMul = MathMax(0.50,MathMin(1.80,instMul));
   fvgMul = MathMax(0.50,MathMin(1.80,fvgMul));
   phaseMul = MathMax(0.50,MathMin(1.80,phaseMul));
   accelPenaltyMul = MathMax(0.50,MathMin(1.80,accelPenaltyMul));
  }

int GetProfileBaseThreshold(const bool partialThreshold)
  {
   int base = partialThreshold ? MathMax(1,InpPartialScoreThreshold) : MathMax(1,InpConfirmScoreThreshold);
   if(InpUseProfileSpecificScoreThresholds)
     {
      if(g_isV751s)
         base = partialThreshold ? MathMax(1,InpPartialScoreThresholdV751s) : MathMax(1,InpConfirmScoreThresholdV751s);
      else
         base = partialThreshold ? MathMax(1,InpPartialScoreThresholdV75) : MathMax(1,InpConfirmScoreThresholdV75);
     }

   if(IsStrongModeActive())
      base += partialThreshold ? MathMax(0,InpStrongPartialThresholdAdd) : MathMax(0,InpStrongConfirmThresholdAdd);
   if(IsScalpModeActive())
      base += partialThreshold ? MathMax(0,InpScalpPartialThresholdAdd) : MathMax(0,InpScalpConfirmThresholdAdd);

   return MathMax(1,base);
  }

double GetProfilePartialLotFactor()
  {
   double f = MathMax(0.10,MathMin(1.0,InpPartialEntryLotFactor));
   if(g_isV751s)
      f = MathMax(0.10,MathMin(1.0,InpPartialEntryLotFactorV751s));
   else
      f = MathMax(0.10,MathMin(1.0,InpPartialEntryLotFactorV75));

   if(IsStrongModeActive())
      f = MathMax(0.10,MathMin(1.0,InpStrongPartialLotFactor));
   if(IsScalpModeActive())
      f = MathMax(0.10,MathMin(1.0,InpScalpPartialLotFactor));
   return f;
  }

int CalculateEntryScore(Direction dir)
  {
   if(!g_entryScoreCtxReady)
      return 0;

   const bool bullish = (dir == DIR_BUY);
   FVGZone zone = g_entryScoreCtxZone;
   double trendMul = 1.0, liqMul = 1.0, instMul = 1.0, fvgMul = 1.0, phaseMul = 1.0, accelPenaltyMul = 1.0;
   GetScoreProfileFactors(trendMul,liqMul,instMul,fvgMul,phaseMul,accelPenaltyMul);

   double score = 0.0;

   // Structure (2-3)
   double structurePts = 0.0;
   bool bos = false, choch = false;
   DetectRecentBOSCHOCH(bullish,bos,choch);
   if(bos)
      structurePts += 0.8;
   if(choch)
      structurePts += 1.0;

   if(bullish)
     {
      double lastHL = 0.0, prevHL = 0.0, lastHH = 0.0, prevHH = 0.0;
      int hlShift = -1;
      if(GetBullTrendAndPullback(lastHL,prevHL,lastHH,prevHH,hlShift))
         structurePts += 1.6;
      if(lastHL > prevHL && lastHH > prevHH)
         structurePts += 0.6;
     }
   else
     {
      double lastLH = 0.0, lastHH = 0.0, lastLL = 0.0, prevHL = 0.0;
      int lhShift = -1;
      if(GetBearTransitionAndPullback(lastLH,lastHH,lastLL,prevHL,lhShift))
         structurePts += 1.6;
      if(lastLL > 0.0 && lastHH > 0.0 && lastLL < lastHH)
         structurePts += 0.4;
     }
   score += MathMin(3.5,MathMax(0.0,structurePts * trendMul));

   // Liquidity (1-2)
   double liquidityPts = 0.0;
   const bool hasSweep = HasLiquiditySweep(bullish) || zone.sweepWick > 0.0;
   if(hasSweep)
      liquidityPts += 1.0;
   double violentRatio = 0.0;
   if(hasSweep && IsViolentDisplacement(bullish,1,violentRatio))
      liquidityPts += 0.8;
   if(!HasOpposingImbalanceNow(bullish))
      liquidityPts += 0.4;
   else
      liquidityPts -= 0.3;
   score += MathMin(2.5,MathMax(-0.8,liquidityPts * liqMul));

   // Institutional (1-2)
   if(InpUseInstitutionalStateModel)
     {
      double instPts = g_entryScoreCtxInstReady ? 1.3 : 0.4;
      if(!HasOpposingImbalanceNow(bullish))
         instPts += 0.6;
      score += MathMin(2.5,MathMax(0.0,instPts * instMul));
     }

   // FVG (1)
   double fvgPts = 0.0;
   const bool sameSide = (zone.bullish == bullish);
   if(sameSide && zone.qualityTier >= 1 && zone.ageBars <= MathMax(12,InpLookbackBars / 20))
      fvgPts += 0.8;
   if(sameSide && zone.fvgRespected)
      fvgPts += 0.3;
   if(sameSide && zone.fvgDisrespected)
      fvgPts -= 0.4;
   if(!bullish && IsV75FVGInversionSell(zone))
      fvgPts += 0.5;
   score += MathMin(1.5,MathMax(-0.7,fvgPts * fvgMul));

   // Regime reweighting
   if(g_entryScoreCtxRegime == REGIME_TREND)
     {
      if(structurePts >= 1.6)
         score += 0.8;
     }
   else if(g_entryScoreCtxRegime == REGIME_RANGE)
     {
      if(hasSweep)
         score += 0.8;
      else
         score -= 0.4;
      if(!IsViolentDisplacement(bullish,1,violentRatio))
         score -= 0.3;
     }
   else if(g_entryScoreCtxRegime == REGIME_HIGHVOL)
     {
      if(IsViolentDisplacement(bullish,1,violentRatio))
         score += 0.5;
      else
         score -= 0.4;
     }

   // Dynamic confidence contribution
   score += GetDynamicConfidenceScoreOffset();

   // Setup tag (0-2 max)
   score += MathMin(2.0,MathMax(0.0,g_entryScoreCtxSetupTagScore));
   if(g_entryScoreCtxSetupTagBlocked)
      score -= 0.6;

   // Pattern / strong constraints converted to weighted contributions.
   if(InpEnablePatternModel)
     {
      if(g_entryScoreCtxPattern >= (InpPatternMinScore + 8.0))
         score += 1.0;
      else if(g_entryScoreCtxPattern >= InpPatternMinScore)
         score += 0.6;
      else if(g_entryScoreCtxPattern >= (InpPatternMinScore - 10.0))
         score += 0.2;
      else
         score -= 0.8;
     }

   const double minAi = GetEffectiveMinAIScore();
   if(g_entryScoreCtxAIScore >= (minAi + 6.0))
      score += 1.0;
   else if(g_entryScoreCtxAIScore >= minAi)
      score += 0.6;
   else if(g_entryScoreCtxAIScore >= (minAi - 8.0))
      score += 0.2;
   else
      score -= 0.8;

   if(g_entryScoreCtxPhase2Pass)
      score += 0.8 * phaseMul;
   else
      score -= 0.4;

   if(g_entryScoreCtxPhase4Pass)
      score += 0.8 * phaseMul;
   else
      score -= 0.4;

   if(InpUseEntryAccelerationFilter && !g_entryScoreCtxAccelPass)
      score -= (1.0 * accelPenaltyMul);

   score = MathMax(0.0,MathMin(12.0,score));
   return (int)MathRound(score);
  }

string LossLearnKey(const string suffix)
  {
   string sym = _Symbol;
   StringReplace(sym," ","_");
   StringReplace(sym,".","_");
   const long login = (long)AccountInfoInteger(ACCOUNT_LOGIN);
   return "ForceXLL_" + IntegerToString((int)login) + "_" + sym + "_" + IntegerToString((int)InpMagic) + "_" + suffix;
  }

void ResetLossLearningState()
  {
   if(!InpEnableLossLearning || !InpLossLearnPersistState)
      return;

   GlobalVariableDel(LossLearnKey("conf"));
   GlobalVariableDel(LossLearnKey("trig"));
   GlobalVariableDel(LossLearnKey("tick"));
   GlobalVariableDel(LossLearnKey("viol"));
   GlobalVariableDel(LossLearnKey("sweep"));
   GlobalVariableDel(LossLearnKey("streak"));
   GlobalVariableDel(LossLearnKey("events"));
   GlobalVariableDel(LossLearnKey("lastdeal"));
  }

void SaveLossLearningState()
  {
   if(!InpEnableLossLearning || !InpLossLearnPersistState)
      return;

   GlobalVariableSet(LossLearnKey("conf"),g_adaptConfidenceAdd);
   GlobalVariableSet(LossLearnKey("trig"),(double)g_adaptTriggerBufAdd);
   GlobalVariableSet(LossLearnKey("tick"),(double)g_adaptTickDelayAdd);
   GlobalVariableSet(LossLearnKey("viol"),g_adaptViolenceAdd);
   GlobalVariableSet(LossLearnKey("sweep"),(double)g_adaptSweepSLAdd);
   GlobalVariableSet(LossLearnKey("streak"),(double)g_lossStreak);
   GlobalVariableSet(LossLearnKey("events"),(double)g_lossLearnEvents);
   GlobalVariableSet(LossLearnKey("lastdeal"),(double)g_lastLearnDeal);
  }

bool LoadLossLearningState()
  {
   if(!InpEnableLossLearning || !InpLossLearnPersistState)
      return false;

   bool loaded = false;
   const string kConf = LossLearnKey("conf");
   const string kTrig = LossLearnKey("trig");
   const string kTick = LossLearnKey("tick");
   const string kViol = LossLearnKey("viol");
   const string kSweep = LossLearnKey("sweep");
   const string kStreak = LossLearnKey("streak");
   const string kEvents = LossLearnKey("events");
   const string kLastDeal = LossLearnKey("lastdeal");

   if(GlobalVariableCheck(kConf))
     {
      g_adaptConfidenceAdd = MathMax(0.0,MathMin(InpLossLearnMaxConfidenceAdd,GlobalVariableGet(kConf)));
      loaded = true;
     }
   if(GlobalVariableCheck(kTrig))
     {
      g_adaptTriggerBufAdd = (int)MathMax(0.0,MathMin((double)InpLossLearnMaxTriggerBufAdd,GlobalVariableGet(kTrig)));
      loaded = true;
     }
   if(GlobalVariableCheck(kTick))
     {
      g_adaptTickDelayAdd = (int)MathMax(0.0,MathMin((double)InpLossLearnMaxTickDelayAdd,GlobalVariableGet(kTick)));
      loaded = true;
     }
   if(GlobalVariableCheck(kViol))
     {
      g_adaptViolenceAdd = MathMax(0.0,MathMin(InpLossLearnMaxViolenceAdd,GlobalVariableGet(kViol)));
      loaded = true;
     }
   if(GlobalVariableCheck(kSweep))
     {
      g_adaptSweepSLAdd = (int)MathMax(0.0,MathMin((double)InpLossLearnMaxSweepSLAdd,GlobalVariableGet(kSweep)));
      loaded = true;
     }
   if(GlobalVariableCheck(kStreak))
     {
      g_lossStreak = (int)MathMax(0.0,GlobalVariableGet(kStreak));
      loaded = true;
     }
   if(GlobalVariableCheck(kEvents))
     {
      g_lossLearnEvents = (int)MathMax(0.0,GlobalVariableGet(kEvents));
      loaded = true;
     }
   if(GlobalVariableCheck(kLastDeal))
     {
      g_lastLearnDeal = (ulong)MathMax(0.0,GlobalVariableGet(kLastDeal));
      loaded = true;
     }

   return loaded;
  }

void LearnFromLosingDeal(const ulong dealTicket)
  {
   if(!InpEnableLossLearning || dealTicket == 0 || dealTicket == g_lastLearnDeal)
      return;

   const long magic = (long)HistoryDealGetInteger(dealTicket,DEAL_MAGIC);
   if(magic != InpMagic)
      return;

   const string sym = HistoryDealGetString(dealTicket,DEAL_SYMBOL);
   if(sym != _Symbol)
      return;

   const long entry = (long)HistoryDealGetInteger(dealTicket,DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT)
      return;

   const double pnl = HistoryDealGetDouble(dealTicket,DEAL_PROFIT) +
                      HistoryDealGetDouble(dealTicket,DEAL_SWAP) +
                      HistoryDealGetDouble(dealTicket,DEAL_COMMISSION);

   if(pnl >= -MathMax(0.0,InpLossLearnMinLossUSD))
     {
      if(pnl > 0.0)
        {
         g_lossStreak = 0; // no positive-learning adjustment, only streak reset
         SaveLossLearningState();
        }
      return;
     }

   g_lastLearnDeal = dealTicket;
   g_lossStreak++;
   g_lossLearnEvents++;

   const double lossAbs = MathAbs(pnl);
   const double scale = MathMax(1.0,MathMin(3.0,lossAbs / MathMax(0.10,InpLossLearnMinLossUSD)));

   g_adaptConfidenceAdd = MathMin(InpLossLearnMaxConfidenceAdd,
                                  g_adaptConfidenceAdd + InpLossLearnConfidenceStep * scale);
   g_adaptTriggerBufAdd = MathMin(InpLossLearnMaxTriggerBufAdd,
                                  g_adaptTriggerBufAdd + MathMax(0,InpLossLearnTriggerBufStep));

   if(g_lossStreak >= MathMax(1,InpLossLearnStreakForHardening))
     {
      g_adaptTickDelayAdd = MathMin(InpLossLearnMaxTickDelayAdd,
                                    g_adaptTickDelayAdd + MathMax(0,InpLossLearnTickDelayStep));
      g_adaptViolenceAdd = MathMin(InpLossLearnMaxViolenceAdd,
                                   g_adaptViolenceAdd + MathMax(0.0,InpLossLearnViolenceStep));
      g_adaptSweepSLAdd = MathMin(InpLossLearnMaxSweepSLAdd,
                                  g_adaptSweepSLAdd + MathMax(0,InpLossLearnSweepSLStep));
     }

   PrintFormat("ForceX LossLearn #%d loss=%.2f streak=%d | conf=%.1f trigBuf=%d tickDelay=%d violent=%.2f sweepSL=%d",
               g_lossLearnEvents,
               pnl,
               g_lossStreak,
               GetAdaptiveExecutionMinConfidence(),
               GetAdaptiveTriggerBufferPoints(),
               GetAdaptiveTriggerTickDelay(),
               GetAdaptiveViolenceMultiplier(),
               GetAdaptiveSweepSLExtraPoints());
   SaveLossLearningState();
  }

bool ParseHHMM(const string hhmm,int &hours,int &mins)
  {
   string parts[];
   if(StringSplit(hhmm,':',parts) != 2)
      return false;

   hours = (int)StringToInteger(parts[0]);
   mins  = (int)StringToInteger(parts[1]);

   if(hours < 0 || hours > 23 || mins < 0 || mins > 59)
      return false;

   return true;
  }

void ParseSessionTimes()
  {
   int sh = 0, sm = 0, eh = 0, em = 0;
   if(ParseHHMM(InpSessionStart,sh,sm) && ParseHHMM(InpSessionEnd,eh,em))
     {
      g_sessStartMins = sh * 60 + sm;
      g_sessEndMins   = eh * 60 + em;
      g_sessionParsed = true;
     }
   else
     {
      g_sessionParsed = false;
     }
  }

bool InSessionWindow()
  {
   if(!InpUseSessionFilter)
      return true;

   if(IsV75ProfileActive() && InpV75DisableSessionFilter)
      return true;

   if(!g_sessionParsed)
      ParseSessionTimes();

   if(!g_sessionParsed)
      return true;

   datetime nowTime = TimeTradeServer();
   if(nowTime <= 0)
      nowTime = TimeCurrent();

   MqlDateTime dt;
   TimeToStruct(nowTime,dt);

   const int nowMins = dt.hour * 60 + dt.min;

   if(g_sessStartMins <= g_sessEndMins)
      return (nowMins >= g_sessStartMins && nowMins <= g_sessEndMins);

   return (nowMins >= g_sessStartMins || nowMins <= g_sessEndMins);
  }

void RefreshDailyState()
  {
   datetime nowTime = TimeTradeServer();
   if(nowTime <= 0)
      nowTime = TimeCurrent();

   MqlDateTime dt;
   TimeToStruct(nowTime,dt);

   const int newDayKey = dt.year * 1000 + dt.day_of_year;
   if(newDayKey != g_dayKey)
     {
      g_dayKey = newDayKey;
      g_tradesToday = 0;
      g_dayLocked = false;
      g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
     }

   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   const double dayPnL = equity - g_dayStartEquity;

   if(InpDailyLossLimitMoney > 0.0 && dayPnL <= -InpDailyLossLimitMoney)
      g_dayLocked = true;

   if(InpDailyProfitTargetMoney > 0.0 && dayPnL >= InpDailyProfitTargetMoney)
      g_dayLocked = true;

   if(!g_enginesInited)
     {
      const int barIdx = CurrentExecBarIndex();
      g_signalEngine.Init(barIdx,MathMax(2,InpFlowStateTimeoutBars),InpDebugMode);
      g_riskEngine.Init(g_dayKey,equity,barIdx,InpDebugMode);
      for(int r = 0; r < ArraySize(g_regimeDisabled); r++)
         g_regimeDisabled[r] = false;
      g_enginesInited = true;
     }
   else
     {
      g_riskEngine.SyncDay(g_dayKey,equity);
      g_riskEngine.Evaluate(equity,
                            CurrentExecBarIndex(),
                            MathMax(0.0,InpDailyDrawdownLimitPct),
                            MathMax(0.0,MaxEquityDrawdownPercent));
     }

   if(g_riskEngine.IsGlobalKilled())
      g_dayLocked = true;
  }

bool IsNewBar(const ENUM_TIMEFRAMES tf,datetime &state)
  {
   datetime t = iTime(_Symbol,tf,0);
   if(t <= 0)
      return false;

   if(t != state)
     {
      state = t;
      return true;
     }

   return false;
  }

bool HasOpenPositionByMagic()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      if((long)PositionGetInteger(POSITION_MAGIC) == InpMagic)
         return true;
     }

   return false;
  }

double NormalizeVolume(const double rawVolume)
  {
   const double vMin  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   const double vMax  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   const double vStep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);

   if(vStep <= 0.0)
      return rawVolume;

   double vol = MathMax(vMin,MathMin(vMax,rawVolume));
   vol = MathFloor(vol / vStep) * vStep;

   if(vol < vMin)
      vol = vMin;

   return vol;
  }

bool IsRetryRetcode(const int retcode)
  {
   return (retcode == TRADE_RETCODE_REQUOTE ||
           retcode == TRADE_RETCODE_PRICE_CHANGED ||
           retcode == TRADE_RETCODE_PRICE_OFF ||
           retcode == TRADE_RETCODE_CONNECTION ||
           retcode == TRADE_RETCODE_TIMEOUT ||
           retcode == TRADE_RETCODE_TOO_MANY_REQUESTS);
  }

bool IsInvalidStopsRetcode(const int retcode)
  {
   return (retcode == TRADE_RETCODE_INVALID_STOPS);
  }

bool IsDirectionTradable(const bool bullish,string &reason)
  {
   const ENUM_SYMBOL_TRADE_MODE mode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE);

   if(mode == SYMBOL_TRADE_MODE_DISABLED)
     {
      reason = "symbol trading disabled";
      return false;
     }
   if(mode == SYMBOL_TRADE_MODE_CLOSEONLY)
     {
      reason = "symbol is close-only";
      return false;
     }
   if(mode == SYMBOL_TRADE_MODE_LONGONLY && !bullish)
     {
      reason = "symbol is long-only (sell blocked)";
      return false;
     }
   if(mode == SYMBOL_TRADE_MODE_SHORTONLY && bullish)
     {
      reason = "symbol is short-only (buy blocked)";
      return false;
     }

   return true;
  }

bool GetFreshTick(MqlTick &tick,string &reason)
  {
   if(!SymbolInfoTick(_Symbol,tick))
     {
      reason = "failed to read symbol tick";
      return false;
     }

   if(tick.bid <= 0.0 || tick.ask <= 0.0)
     {
      reason = "invalid bid/ask";
      return false;
     }

   if(InpUseMarketModel && InpMaxTickAgeSec > 0)
     {
      datetime nowTime = TimeTradeServer();
      if(nowTime <= 0)
         nowTime = TimeCurrent();

      if(nowTime > 0 && tick.time > 0 && (nowTime - tick.time) > InpMaxTickAgeSec)
        {
         reason = "stale tick";
         return false;
        }
     }

   return true;
  }

bool ValidateMarketModel(const bool bullish,const double volume,const MqlTick &tick,string &reason)
  {
   if(!InpUseMarketModel)
      return true;

   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
     {
      reason = "terminal disconnected";
      return false;
     }

   if(!MQLInfoInteger(MQL_TRADE_ALLOWED) || !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
     {
      reason = "algo/terminal trading disabled";
      return false;
     }

   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
     {
      reason = "account trading not allowed";
      return false;
     }

   if(!IsDirectionTradable(bullish,reason))
      return false;

   const double spreadPts = (tick.ask - tick.bid) / _Point;
   int maxSpreadPts = GetEffectiveMaxSpreadPoints();
   if(IsStrongModeActive() && InpStrongMaxSpreadPoints > 0)
      maxSpreadPts = (maxSpreadPts > 0) ? MathMin(maxSpreadPts,InpStrongMaxSpreadPoints) : InpStrongMaxSpreadPoints;

   if(maxSpreadPts > 0 && spreadPts > maxSpreadPts)
     {
      reason = "spread too high";
      return false;
     }

   const double avgSpreadPts = GetAverageSpreadPoints(16);
   if(g_execEngine.IsSpreadSpike(spreadPts,avgSpreadPts,InpSpreadSpikeFilterMultiplier))
     {
      reason = "spread spike filter";
      return false;
     }

   if(InpUseSpreadToRangeGuard && InpMaxSpreadToRangePct > 0.0)
     {
      const double h1 = iHigh(_Symbol,InpExecutionTF,1);
      const double l1 = iLow(_Symbol,InpExecutionTF,1);
      const double rangePts = MathMax((h1 - l1) / _Point,1.0);
      const double spreadPct = 100.0 * (spreadPts / rangePts);
      if(spreadPct > InpMaxSpreadToRangePct)
        {
         reason = "spread/range guard";
         return false;
        }
     }

   const ENUM_ORDER_TYPE orderType = bullish ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   const double price = bullish ? tick.ask : tick.bid;
   double margin = 0.0;
   if(!OrderCalcMargin(orderType,_Symbol,volume,price,margin))
     {
      reason = "margin calculation failed";
      return false;
     }

   if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) < margin)
     {
      reason = "insufficient free margin";
      return false;
     }

   return true;
  }

bool BuildOrderLevels(const bool bullish,const FVGZone &zone,const MqlTick &tick,double &sl,double &tp,string &reason)
  {
   const int slBufferPts = MathMax(0,GetEffectiveSLBufferPoints());
   double rrBase = GetEffectiveRiskReward();
   if(InpUseV75DualSMCExecution && IsV75ProfileActive())
      rrBase = MathMax(rrBase,InpV75MinRR);
   const double rr = MathMax(0.5,rrBase);
   const double entry = bullish ? tick.ask : tick.bid;
   const int stopLevelPts = (int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   const int freezeLevelPts = (int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   const int spreadPts = (int)MathCeil((tick.ask - tick.bid) / _Point);
   const int safetyPts = MathMax(0,InpStopSafetyExtraPoints);
   const int v75MinPts = GetEffectiveMinStopDistancePoints();
   const int minLevelPts = MathMax(MathMax(MathMax(stopLevelPts,freezeLevelPts),spreadPts + safetyPts),MathMax(v75MinPts,1));
   const double minDistance = minLevelPts * _Point;
   const double atrPts = MathMax(1.0,ComputeATRPoints(MathMax(6,InpSupervisorP4ATRPeriod)));
   const double rangePtsNow = MathMax((iHigh(_Symbol,InpExecutionTF,1) - iLow(_Symbol,InpExecutionTF,1)) / _Point,1.0);
   const double adaptiveBufferPts = MathMax((double)slBufferPts,atrPts * 0.35);
   const double tpExpansionPts = MathMax(atrPts * MathMax(0.5,InpTPAtrMultiplier),
                                         rangePtsNow * MathMax(0.5,InpTPRangeExpansionMult));

   if(bullish)
     {
      if(InpUseV75DualSMCExecution && IsV75ProfileActive() && zone.sweepWick > 0.0)
         sl = zone.sweepWick - (GetAdaptiveSweepSLExtraPoints() + adaptiveBufferPts) * _Point;
      else
         sl = zone.lower - adaptiveBufferPts * _Point;
      if((entry - sl) < minDistance)
         sl = entry - minDistance;
      if(sl <= 0.0 || sl >= entry)
        {
         reason = "invalid buy stop loss";
         return false;
        }

      const double rrTP = entry + (entry - sl) * rr;
      const double expansionTP = entry + tpExpansionPts * _Point;
      tp = MathMax(rrTP,expansionTP);
      if(InpUseV75DualSMCExecution && IsV75ProfileActive() && zone.targetLiquidity > entry)
         tp = MathMax(tp,zone.targetLiquidity);
      if((tp - entry) < minDistance)
         tp = entry + minDistance;
      if(tp <= entry)
        {
         reason = "invalid buy take profit";
         return false;
        }
     }
   else
     {
      if(InpUseV75DualSMCExecution && IsV75ProfileActive() && zone.sweepWick > 0.0)
         sl = zone.sweepWick + (GetAdaptiveSweepSLExtraPoints() + adaptiveBufferPts) * _Point;
      else
         sl = zone.upper + adaptiveBufferPts * _Point;
      if((sl - entry) < minDistance)
         sl = entry + minDistance;
      if(sl <= entry)
        {
         reason = "invalid sell stop loss";
         return false;
        }

      const double rrTP = entry - (sl - entry) * rr;
      const double expansionTP = entry - tpExpansionPts * _Point;
      tp = MathMin(rrTP,expansionTP);
      if(InpUseV75DualSMCExecution && IsV75ProfileActive() && zone.targetLiquidity > 0.0 && zone.targetLiquidity < entry)
         tp = MathMin(tp,zone.targetLiquidity);
      if((entry - tp) < minDistance)
         tp = entry - minDistance;
      if(tp <= 0.0 || tp >= entry)
        {
         reason = "invalid sell take profit";
         return false;
        }
     }

   sl = NormalizeDouble(sl,_Digits);
   tp = NormalizeDouble(tp,_Digits);
   return true;
  }

bool BuildEmergencyLevelsFromMarket(const bool bullish,const MqlTick &tick,double &sl,double &tp)
  {
   const double rr = MathMax(0.5,GetEffectiveRiskReward());
   const int stopLevelPts = (int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   const int freezeLevelPts = (int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   const int spreadPts = (int)MathCeil((tick.ask - tick.bid) / _Point);
   const int safetyPts = MathMax(0,InpStopSafetyExtraPoints);
   const int v75MinPts = GetEffectiveMinStopDistancePoints();
   const int minLevelPts = MathMax(MathMax(MathMax(stopLevelPts,freezeLevelPts),spreadPts + safetyPts),MathMax(v75MinPts,1));
   const double dist = minLevelPts * _Point;

   if(bullish)
     {
      sl = tick.bid - dist;
      tp = tick.ask + dist * MathMax(rr,1.0);
      if(sl <= 0.0 || sl >= tick.bid)
         return false;
      if(tp <= tick.ask)
         tp = tick.ask + dist;
     }
   else
     {
      sl = tick.ask + dist;
      tp = tick.bid - dist * MathMax(rr,1.0);
      if(sl <= tick.ask)
         return false;
      if(tp <= 0.0 || tp >= tick.bid)
         tp = tick.bid - dist;
     }

   sl = NormalizeDouble(sl,_Digits);
   tp = NormalizeDouble(tp,_Digits);
   return true;
  }

bool FindMagicPosition(ulong &ticket,long &type)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;

      ticket = t;
      type = PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

bool AttachProtectiveStopsAfterEntry(const bool bullish,const FVGZone &zone,string &reason)
  {
   const int attempts = MathMax(1,InpRescueAttachAttempts);
   for(int a = 0; a < attempts; a++)
     {
      ulong ticket = 0;
      long pType = -1;
      if(!FindMagicPosition(ticket,pType))
        {
         if(InpRescueAttachDelayMs > 0)
            Sleep(InpRescueAttachDelayMs);
         continue;
        }

      if((bullish && pType != POSITION_TYPE_BUY) || (!bullish && pType != POSITION_TYPE_SELL))
        {
         reason = "rescue position type mismatch";
         return false;
        }

      MqlTick tick;
      if(!GetFreshTick(tick,reason))
        {
         if(InpRescueAttachDelayMs > 0)
            Sleep(InpRescueAttachDelayMs);
         continue;
        }

      double sl = 0.0;
      double tp = 0.0;
      if(!BuildOrderLevels(bullish,zone,tick,sl,tp,reason))
        {
         if(InpRescueAttachDelayMs > 0)
            Sleep(InpRescueAttachDelayMs);
         continue;
        }

      if(g_trade.PositionModify(ticket,sl,tp))
         return true;

      const int rc = (int)g_trade.ResultRetcode();
      if(IsInvalidStopsRetcode(rc) || IsRetryRetcode(rc))
        {
         if(InpRescueAttachDelayMs > 0)
            Sleep(InpRescueAttachDelayMs);
         continue;
        }

      reason = g_trade.ResultRetcodeDescription();
      return false;
     }

   ulong ticket = 0;
   long pType = -1;
   MqlTick tick;
   if(FindMagicPosition(ticket,pType) &&
      ((bullish && pType == POSITION_TYPE_BUY) || (!bullish && pType == POSITION_TYPE_SELL)) &&
      GetFreshTick(tick,reason))
     {
      double sl = 0.0;
      double tp = 0.0;
      if(BuildEmergencyLevelsFromMarket(bullish,tick,sl,tp) && g_trade.PositionModify(ticket,sl,tp))
         return true;
     }

   reason = "rescue SL/TP attach attempts exhausted";
   return false;
  }

double ComputePatternScore(const FVGZone &zone,string &phaseTag)
  {
   if(!InpEnablePatternModel)
     {
      phaseTag = "off";
      return 100.0;
     }

   const int bars = Bars(_Symbol,InpExecutionTF);
   int lookback = MathMax(6,InpPatternLookbackBars);
   lookback = MathMin(lookback,bars - 3);
   if(lookback < 4)
     {
      phaseTag = "data_low";
      return 50.0;
     }

   int structureHits = 0;
   double directionalBody = 0.0;
   double totalBody = 0.0;
   double rangeSum = 0.0;

   for(int i = 1; i <= lookback; i++)
     {
      const double h0 = iHigh(_Symbol,InpExecutionTF,i);
      const double h1 = iHigh(_Symbol,InpExecutionTF,i+1);
      const double l0 = iLow(_Symbol,InpExecutionTF,i);
      const double l1 = iLow(_Symbol,InpExecutionTF,i+1);

      if(zone.bullish)
        {
         if(h0 > h1 && l0 > l1)
            structureHits++;
        }
      else
        {
         if(h0 < h1 && l0 < l1)
            structureHits++;
        }

      const double o = iOpen(_Symbol,InpExecutionTF,i);
      const double c = iClose(_Symbol,InpExecutionTF,i);
      const double body = MathAbs(c - o);
      const double signedMove = zone.bullish ? (c - o) : (o - c);
      if(signedMove > 0.0)
         directionalBody += signedMove;
      totalBody += body;

      rangeSum += MathMax(h0 - l0,_Point);
     }

   const double structureScore = 100.0 * ((double)structureHits / (double)lookback);
   const double momentumScore = (totalBody > 0.0) ? (100.0 * directionalBody / totalBody) : 50.0;

   const double avgRange = rangeSum / lookback;
   const double recentRange = MathMax(iHigh(_Symbol,InpExecutionTF,1) - iLow(_Symbol,InpExecutionTF,1),_Point);
   const double rangeRatio = recentRange / MathMax(avgRange,_Point);
   double volatilityScore = 100.0 - MathMin(100.0,MathAbs(rangeRatio - 1.15) * 65.0);
   volatilityScore = MathMax(0.0,volatilityScore);

   const double ws = MathMax(0.0,InpPatternWStructure);
   const double wm = MathMax(0.0,InpPatternWMomentum);
   const double wv = MathMax(0.0,InpPatternWVolatility);
   const double wsum = ws + wm + wv;
   double score = (wsum > 0.0) ?
                  ((structureScore * ws + momentumScore * wm + volatilityScore * wv) / wsum) :
                  ((structureScore + momentumScore + volatilityScore) / 3.0);
   score = MathMax(0.0,MathMin(100.0,score));

   if(structureScore >= 65.0 && momentumScore >= 60.0)
      phaseTag = zone.bullish ? "trend_up" : "trend_dn";
   else if(structureScore <= 35.0 && momentumScore <= 45.0)
      phaseTag = "chop";
   else
      phaseTag = "mixed";

   return score;
  }

bool PassPatternModel(const FVGZone &zone,double &patternScore,string &phaseTag,string &reason)
  {
   patternScore = 100.0;
   phaseTag = "off";
   reason = "";

   if(!InpEnablePatternModel)
      return true;

   patternScore = ComputePatternScore(zone,phaseTag);
   if(patternScore < InpPatternMinScore)
     {
      reason = "pattern score " + DoubleToString(patternScore,1) + " (" + phaseTag + ")";
      return false;
     }

   return true;
  }

bool PassStrongEntryFilters(const FVGZone &zone,string &reason)
  {
   if(!IsStrongModeActive())
      return true;

   if(InpStrongRequireBias && !BiasAllowsDirection(zone.bullish))
     {
      reason = "strong mode bias filter";
      return false;
     }

   if(InpStrongRequireLiquiditySweep && !HasLiquiditySweep(zone.bullish))
     {
      reason = "strong mode liquidity filter";
      return false;
     }

   if(InpStrongRequireMTFOverlap && !HasMTFOverlap(zone))
     {
      reason = "strong mode MTF overlap filter";
      return false;
     }

   if(InpStrongRequireOBAlignment && !ValidateOrderBlockConfluence(zone.bullish,zone))
     {
      reason = "strong mode OB filter";
      return false;
     }

   const int sec = PeriodSeconds(InpExecutionTF);
   if(sec > 0 && InpStrongMaxZoneAgeBars > 0)
     {
      const int ageBars = (int)((TimeCurrent() - zone.time1) / sec);
      if(ageBars > InpStrongMaxZoneAgeBars)
        {
         reason = "zone too old for strong mode";
         return false;
        }
     }

   if(InpStrongRequireRetestCandle)
     {
      const double tol = InpStrongRetestTolerancePoints * _Point;
      const double o1 = iOpen(_Symbol,InpExecutionTF,1);
      const double c1 = iClose(_Symbol,InpExecutionTF,1);
      const double h1 = iHigh(_Symbol,InpExecutionTF,1);
      const double l1 = iLow(_Symbol,InpExecutionTF,1);

      if(zone.bullish)
        {
         const bool touched = (l1 <= (zone.lower + tol));
         const bool rejected = (c1 > zone.lower);
         const bool dir = (c1 > o1);
         if(!(touched && rejected && dir))
           {
            reason = "bull retest candle not confirmed";
            return false;
           }
        }
      else
        {
         const bool touched = (h1 >= (zone.lower - tol));
         const bool rejected = (c1 < zone.lower);
         const bool dir = (c1 < o1);
         if(!(touched && rejected && dir))
           {
            reason = "bear retest candle not confirmed";
            return false;
           }
        }
     }

   return true;
  }

bool IsSwingHighAt(const int shift,const int wing)
  {
   const int bars = Bars(_Symbol,InpExecutionTF);
   if(shift <= wing || shift + wing >= bars)
      return false;

   const double px = iHigh(_Symbol,InpExecutionTF,shift);
   for(int k = 1; k <= wing; k++)
     {
      if(px <= iHigh(_Symbol,InpExecutionTF,shift-k))
         return false;
      if(px < iHigh(_Symbol,InpExecutionTF,shift+k))
         return false;
     }
   return true;
  }

bool IsSwingLowAt(const int shift,const int wing)
  {
   const int bars = Bars(_Symbol,InpExecutionTF);
   if(shift <= wing || shift + wing >= bars)
      return false;

   const double px = iLow(_Symbol,InpExecutionTF,shift);
   for(int k = 1; k <= wing; k++)
     {
      if(px >= iLow(_Symbol,InpExecutionTF,shift-k))
         return false;
      if(px > iLow(_Symbol,InpExecutionTF,shift+k))
         return false;
     }
   return true;
  }

bool BuildRecentSwings(SwingPoint &swings[],const int lookback,const int wing)
  {
   ArrayResize(swings,0);

   const int bars = Bars(_Symbol,InpExecutionTF);
   if(bars < lookback + wing + 5)
      return false;

   double lastHigh = 0.0;
   double lastLow = 0.0;
   bool hasHigh = false;
   bool hasLow = false;
   bool hasLastType = false;
   bool lastWasHigh = false;

   for(int i = lookback; i >= wing + 1; i--)
     {
      const bool isHigh = IsSwingHighAt(i,wing);
      const bool isLow = IsSwingLowAt(i,wing);
      if(!isHigh && !isLow)
         continue;

      bool chooseHigh = isHigh;
      if(isHigh && isLow)
        {
         const double upWick = iHigh(_Symbol,InpExecutionTF,i) - MathMax(iOpen(_Symbol,InpExecutionTF,i),iClose(_Symbol,InpExecutionTF,i));
         const double dnWick = MathMin(iOpen(_Symbol,InpExecutionTF,i),iClose(_Symbol,InpExecutionTF,i)) - iLow(_Symbol,InpExecutionTF,i);
         chooseHigh = (upWick >= dnWick);
        }

      if(hasLastType && chooseHigh == lastWasHigh)
         continue;

      SwingPoint sp;
      sp.shift = i;
      sp.isHigh = chooseHigh;
      sp.price = chooseHigh ? iHigh(_Symbol,InpExecutionTF,i) : iLow(_Symbol,InpExecutionTF,i);
      sp.label = SWING_NONE;

      if(sp.isHigh)
        {
         if(hasHigh)
            sp.label = (sp.price > lastHigh) ? SWING_HH : SWING_LH;
         lastHigh = sp.price;
         hasHigh = true;
        }
      else
        {
         if(hasLow)
            sp.label = (sp.price > lastLow) ? SWING_HL : SWING_LL;
         lastLow = sp.price;
         hasLow = true;
        }

      const int n = ArraySize(swings);
      ArrayResize(swings,n+1);
      swings[n] = sp;
      hasLastType = true;
      lastWasHigh = sp.isHigh;
     }

   return (ArraySize(swings) >= 4);
  }

bool GetBullTrendAndPullback(double &lastHL,double &prevHL,double &lastHH,double &prevHH,int &hlShift)
  {
   lastHL = 0.0;
   prevHL = 0.0;
   lastHH = 0.0;
   prevHH = 0.0;
   hlShift = -1;

   SwingPoint swings[];
   const int lookback = MathMax(80,InpPatternLookbackBars * 5);
   if(!BuildRecentSwings(swings,lookback,2))
      return false;

   const int n = ArraySize(swings);
   for(int i = n - 1; i >= 3; i--)
     {
      const SwingPoint s0 = swings[i];
      const SwingPoint s1 = swings[i-1];
      const SwingPoint s2 = swings[i-2];
      const SwingPoint s3 = swings[i-3];

      if(!s0.isHigh && s1.isHigh && !s2.isHigh && s3.isHigh &&
         s0.label == SWING_HL && s1.label == SWING_HH &&
         s2.label == SWING_HL && s3.label == SWING_HH &&
         s1.price > s3.price && s0.price > s2.price)
        {
         lastHL = s0.price;
         prevHL = s2.price;
         lastHH = s1.price;
         prevHH = s3.price;
         hlShift = s0.shift;
         return true;
        }
     }

   return false;
  }

bool GetBearTransitionAndPullback(double &lastLH,double &lastHH,double &lastLL,double &prevHL,int &lhShift)
  {
   lastLH = 0.0;
   lastHH = 0.0;
   lastLL = 0.0;
   prevHL = 0.0;
   lhShift = -1;

   SwingPoint swings[];
   const int lookback = MathMax(80,InpPatternLookbackBars * 5);
   if(!BuildRecentSwings(swings,lookback,2))
      return false;

   const int n = ArraySize(swings);
   for(int i = n - 1; i >= 4; i--)
     {
      const SwingPoint s0 = swings[i];
      const SwingPoint s1 = swings[i-1];
      const SwingPoint s2 = swings[i-2];
      const SwingPoint s3 = swings[i-3];
      const SwingPoint s4 = swings[i-4];

      if(s0.isHigh && !s1.isHigh && s2.isHigh && !s3.isHigh && s4.isHigh &&
         s0.label == SWING_LH && s1.label == SWING_LL &&
         s3.label == SWING_HL && s4.label == SWING_HH &&
         s1.price < s3.price && s0.price < s4.price)
        {
         lastLH = s0.price;
         lastHH = s4.price;
         lastLL = s1.price;
         prevHL = s3.price;
         lhShift = s0.shift;
         return true;
        }
     }

   return false;
  }

bool BullWickRejectionAtShift(const int shift,const int minPts)
  {
   if(shift < 1)
      return false;

   const double o = iOpen(_Symbol,InpExecutionTF,shift);
   const double c = iClose(_Symbol,InpExecutionTF,shift);
   const double h = iHigh(_Symbol,InpExecutionTF,shift);
   const double l = iLow(_Symbol,InpExecutionTF,shift);

   const double lowWick = MathMin(o,c) - l;
   const double upWick = h - MathMax(o,c);
   const double body = MathAbs(c - o);

   return (lowWick >= minPts * _Point && lowWick > upWick && (c >= o || lowWick > body));
  }

bool BearWickRejectionAtShift(const int shift,const int minPts)
  {
   if(shift < 1)
      return false;

   const double o = iOpen(_Symbol,InpExecutionTF,shift);
   const double c = iClose(_Symbol,InpExecutionTF,shift);
   const double h = iHigh(_Symbol,InpExecutionTF,shift);
   const double l = iLow(_Symbol,InpExecutionTF,shift);

   const double upWick = h - MathMax(o,c);
   const double lowWick = MathMin(o,c) - l;
   const double body = MathAbs(c - o);

   return (upWick >= minPts * _Point && upWick > lowWick && (c <= o || upWick > body));
  }

bool GetRecentSwingLevel(const ENUM_TIMEFRAMES tf,const bool high,const int lookback,double &level,int &shift)
  {
   level = 0.0;
   shift = -1;
   const int bars = Bars(_Symbol,tf);
   if(bars < lookback + 10)
      return false;

   const int wing = 2;
   for(int i = wing + 2; i <= lookback; i++)
     {
      bool isSwing = true;
      if(high)
        {
         const double px = iHigh(_Symbol,tf,i);
         for(int k = 1; k <= wing; k++)
           {
            if(px <= iHigh(_Symbol,tf,i-k) || px < iHigh(_Symbol,tf,i+k))
              {
               isSwing = false;
               break;
              }
           }
        }
      else
        {
         const double px = iLow(_Symbol,tf,i);
         for(int k = 1; k <= wing; k++)
           {
            if(px >= iLow(_Symbol,tf,i-k) || px > iLow(_Symbol,tf,i+k))
              {
               isSwing = false;
               break;
              }
           }
        }

      if(!isSwing)
         continue;

      shift = i;
      level = high ? iHigh(_Symbol,tf,i) : iLow(_Symbol,tf,i);
      return true;
     }

   return false;
  }

bool IsViolentDisplacement(const bool bullish,const int shift,double &ratioOut)
  {
   ratioOut = 0.0;
   const int bars = Bars(_Symbol,InpExecutionTF);
   const int n = MathMax(3,InpV75ViolenceLookback);
   if(bars < shift + n + 4)
      return false;

   const double o = iOpen(_Symbol,InpExecutionTF,shift);
   const double c = iClose(_Symbol,InpExecutionTF,shift);
   const double body = MathAbs(c - o);
   if(body <= 0.0)
      return false;

   double sum = 0.0;
   int used = 0;
   for(int i = shift + 1; i <= shift + n; i++)
     {
      const double oi = iOpen(_Symbol,InpExecutionTF,i);
      const double ci = iClose(_Symbol,InpExecutionTF,i);
      const double bi = MathAbs(ci - oi);
      if(bi <= 0.0)
         continue;
      sum += bi;
      used++;
     }

   if(used < 3 || sum <= 0.0)
      return false;

   const double avg = sum / used;
   ratioOut = body / avg;

   if(bullish && c <= o)
      return false;
   if(!bullish && c >= o)
      return false;

   return (ratioOut >= GetAdaptiveViolenceMultiplier());
  }

bool EvaluateV75DualSMCStates(FVGZone &zone,const double bid,const double ask,string &stateTag)
  {
   stateTag = "";
   if(!InpUseV75DualSMCExecution || !IsV75ProfileActive())
      return false;

   const double tol = MathMax(1,GetAdaptiveTriggerBufferPoints()) * _Point;
   const double o1 = iOpen(_Symbol,InpExecutionTF,1);
   const double c1 = iClose(_Symbol,InpExecutionTF,1);
   const double h1 = iHigh(_Symbol,InpExecutionTF,1);
   const double l1 = iLow(_Symbol,InpExecutionTF,1);
   const double o2 = iOpen(_Symbol,InpExecutionTF,2);
   const double c2 = iClose(_Symbol,InpExecutionTF,2);
   const double h2 = iHigh(_Symbol,InpExecutionTF,2);
   const double l2 = iLow(_Symbol,InpExecutionTF,2);

   double confidence = 0.0;
   zone.doubleSweep = false;
   zone.fvgRespected = false;
   zone.fvgDisrespected = false;
   zone.targetLiquidity = 0.0;
   zone.sweepWick = 0.0;
   zone.flowState = FLOW_IDLE;

   double m1Swing = 0.0, m5Swing = 0.0;
   int sh1 = -1, sh5 = -1;
   const bool hasM1 = GetRecentSwingLevel(PERIOD_M1,zone.bullish ? false : true,80,m1Swing,sh1);
   const bool hasM5 = GetRecentSwingLevel(PERIOD_M5,zone.bullish ? false : true,80,m5Swing,sh5);
   if(!hasM1 && !hasM5)
      return false;

   const double sweepLevel = (hasM1 && hasM5) ?
                             (zone.bullish ? MathMin(m1Swing,m5Swing) : MathMax(m1Swing,m5Swing)) :
                             (hasM1 ? m1Swing : m5Swing);

   bool sweep = false;
   if(zone.bullish)
      sweep = (l1 < (sweepLevel - tol) && c1 > sweepLevel);
   else
      sweep = (h1 > (sweepLevel + tol) && c1 < sweepLevel);
   if(!sweep)
      return false;

   zone.flowState = FLOW_LIQUIDITY_SWEEP;
   zone.sweepWick = zone.bullish ? l1 : h1;
   zone.structureLevel = sweepLevel;
   confidence += 30.0;
   stateTag = "SWEEP";

   if(zone.bullish && InpV75EnableDoubleSweep)
     {
      const bool firstSweep = (l2 < (sweepLevel - tol) && c2 > sweepLevel);
      const bool secondDeeper = (l1 < l2);
      if(firstSweep && secondDeeper)
        {
         zone.doubleSweep = true;
         confidence += 15.0;
         stateTag += "+D2";
        }
     }

   double m1Break = 0.0, m5Break = 0.0;
   int br1 = -1, br5 = -1;
   const bool hasBreakM1 = GetRecentSwingLevel(PERIOD_M1,zone.bullish ? true : false,80,m1Break,br1);
   const bool hasBreakM5 = GetRecentSwingLevel(PERIOD_M5,zone.bullish ? true : false,80,m5Break,br5);
   if(!hasBreakM1 && !hasBreakM5)
      return false;

   const double breakLevel = (hasBreakM1 && hasBreakM5) ?
                             (zone.bullish ? MathMax(m1Break,m5Break) : MathMin(m1Break,m5Break)) :
                             (hasBreakM1 ? m1Break : m5Break);
   const bool structureBreak = zone.bullish ? (c1 > breakLevel) : (c1 < breakLevel);
   if(!structureBreak)
      return false;

   zone.flowState = FLOW_CONFIRMATION_STATE;
   confidence += 30.0;
   stateTag += ">MSS";

   bool bos = false;
   bool choch = false;
   DetectRecentBOSCHOCH(zone.bullish,bos,choch);
   zone.bosAligned = bos;
   zone.chochAligned = choch;
   if(choch)
     {
      confidence += 20.0;
      stateTag += ">CHOCH";
     }
   else if(bos)
     {
      confidence += 12.0;
      stateTag += ">BOS";
     }
   else
     {
      confidence -= 8.0;
      stateTag += ">NOBOS";
      if(InpUseSupervisorPhase3 && InpSupervisorRequireBosOrChochFlow)
         return false;
     }

   double violentRatio = 0.0;
   if(!IsViolentDisplacement(zone.bullish,1,violentRatio))
      return false;
   confidence += 20.0;
   stateTag += ">V" + DoubleToString(violentRatio,2);

   zone.fvgRespected = zone.bullish ?
                       (l1 <= (zone.upper + tol) && c1 >= (zone.lower - tol)) :
                       (h1 >= (zone.lower - tol) && c1 <= (zone.upper + tol));
   zone.fvgDisrespected = zone.bullish ?
                          (c1 < (zone.lower - tol)) :
                          (c1 > (zone.upper + tol));
   if(zone.fvgRespected)
      confidence += 10.0;
   if(zone.fvgDisrespected)
      confidence -= 20.0;

   double targetM1 = 0.0, targetM5 = 0.0;
   int tg1 = -1, tg5 = -1;
   const bool hasT1 = GetRecentSwingLevel(PERIOD_M1,zone.bullish ? true : false,140,targetM1,tg1);
   const bool hasT5 = GetRecentSwingLevel(PERIOD_M5,zone.bullish ? true : false,140,targetM5,tg5);
   if(hasT1 && hasT5)
     {
      if(zone.bullish)
         zone.targetLiquidity = (targetM1 > ask && targetM5 > ask) ? MathMin(targetM1,targetM5) : MathMax(targetM1,targetM5);
      else
         zone.targetLiquidity = (targetM1 < bid && targetM5 < bid) ? MathMax(targetM1,targetM5) : MathMin(targetM1,targetM5);
     }
   else if(hasT1)
      zone.targetLiquidity = targetM1;
   else if(hasT5)
      zone.targetLiquidity = targetM5;

   const datetime currBar = iTime(_Symbol,InpExecutionTF,0);
   if(currBar <= 0)
      return false;

   if(zone.gateBarTime != currBar)
     {
      zone.gateBarTime = currBar;
      zone.gateTicks = 0;
     }

   bool entryPriceReady = true;
   if(!InpV75AggressiveEntry)
     {
      const double retr = MathMax(0.0,MathMin(100.0,InpV75ConservativeRetracePct)) / 100.0;
      const double retraceLevel = zone.bullish ?
                                  (l1 + (h1 - l1) * retr) :
                                  (h1 - (h1 - l1) * retr);
      entryPriceReady = zone.bullish ? (bid <= (retraceLevel + tol)) : (ask >= (retraceLevel - tol));
      if(entryPriceReady)
         stateTag += ">R";
      else
         return false;
     }

   zone.gateTicks++;
   const int tickDelay = GetAdaptiveTriggerTickDelay();
   const int execTick = MathMax(MathMax(1,InpTriggerExecuteTick),tickDelay + 1);

   if(zone.gateTicks <= tickDelay)
      return false;
   if(zone.gateTicks < execTick)
      return false;

   if(zone.bullish && bid <= (zone.structureLevel + tol))
      return false;
   if(!zone.bullish && ask >= (zone.structureLevel - tol))
      return false;

   const double spreadPts = (ask - bid) / _Point;
   const int maxSpreadPts = GetEffectiveMaxSpreadPoints();
   if(maxSpreadPts > 0 && spreadPts > maxSpreadPts)
      return false;

   if(InpTriggerBlockOpposingImbalance && HasOpposingImbalanceNow(zone.bullish))
      return false;

   if(InpUseSupervisorPhase3)
     {
      const int regime = GetCurrentMarketRegime();
      if(regime == REGIME_RANGE)
        {
         confidence -= 6.0;
         stateTag += ">RNG";
         if(!zone.fvgRespected)
            return false;
        }
      else if(regime == REGIME_HIGHVOL)
        {
         confidence -= 8.0;
         stateTag += ">HV";
        }
      else
         stateTag += ">TRD";
     }

   zone.confidence = MathMax(0.0,MathMin(100.0,confidence));
   if(zone.confidence < GetAdaptiveExecutionMinConfidence())
      return false;

   zone.flowState = FLOW_EXECUTION_STATE;
   stateTag += ">EXEC";
   return entryPriceReady;
  }

bool IsV75FVGInversionSell(const FVGZone &zone)
  {
   if(!InpUseV75DualSMCExecution || !InpV75EnableFVGInversion || !IsV75ProfileActive())
      return false;
   if(!zone.bullish)
      return false;

   const double tol = MathMax(1,GetAdaptiveTriggerBufferPoints()) * _Point;
   const double o1 = iOpen(_Symbol,InpExecutionTF,1);
   const double c1 = iClose(_Symbol,InpExecutionTF,1);
   const double l1 = iLow(_Symbol,InpExecutionTF,1);
   const double c2 = iClose(_Symbol,InpExecutionTF,2);
   const double c3 = iClose(_Symbol,InpExecutionTF,3);

   const bool touched = (l1 <= (zone.upper + tol));
   const bool pierced = (c1 < (zone.lower - tol));
   const bool bearish = (c1 < o1);
   const bool dropping = (c2 < c3);
   return (touched && pierced && bearish && dropping);
  }

bool HasOpposingImbalanceNow(const bool bullish)
  {
   if(Bars(_Symbol,InpExecutionTF) < 8)
      return false;

   if(bullish)
      return (iLow(_Symbol,InpExecutionTF,3) > iHigh(_Symbol,InpExecutionTF,1));

   return (iLow(_Symbol,InpExecutionTF,1) > iHigh(_Symbol,InpExecutionTF,3));
  }

int CountOppositeFVGs(const bool bullishPosition)
  {
   int count = 0;
   for(int i = 0; i < ArraySize(g_zones); i++)
     {
      if(!g_zones[i].active)
         continue;
      if(g_zones[i].bullish == bullishPosition)
         continue;
      count++;
     }
   return count;
  }

bool EvaluateInstitutionalStates(FVGZone &zone,const double bid,const double ask,string &stateTag)
  {
   stateTag = "";

   if(!InpUseInstitutionalStateModel)
      return true;

   if(InpUseV75DualSMCExecution && IsV75ProfileActive())
      return EvaluateV75DualSMCStates(zone,bid,ask,stateTag);

   double confidence = 0.0;
   int pullShift = -1;
   double structureLevel = 0.0;
   double prevStructureLevel = 0.0;

   if(zone.bullish)
     {
      double lastHH = 0.0, prevHH = 0.0;
      if(!GetBullTrendAndPullback(structureLevel,prevStructureLevel,lastHH,prevHH,pullShift))
        {
         zone.flowState = FLOW_IDLE;
         return false;
        }
      zone.flowState = FLOW_TREND_STATE;
      confidence += 30.0;
      stateTag = "TREND";
     }
   else
     {
      double lastHH = 0.0, lastLL = 0.0;
      if(!GetBearTransitionAndPullback(structureLevel,lastHH,lastLL,prevStructureLevel,pullShift))
        {
         zone.flowState = FLOW_IDLE;
         return false;
        }
      zone.flowState = FLOW_TREND_STATE;
      confidence += 30.0;
      stateTag = "TREND";
     }

   zone.structureLevel = structureLevel;

   const bool wickReject = zone.bullish ?
                           BullWickRejectionAtShift(pullShift,MathMax(1,InpWickSweepMinPoints)) :
                           BearWickRejectionAtShift(pullShift,MathMax(1,InpWickSweepMinPoints));

   zone.flowState = FLOW_PULLBACK_STATE;
   if(wickReject)
      confidence += 15.0;
   else
      confidence -= 10.0;
   stateTag += ">PULLBACK";

   const double c1 = iClose(_Symbol,InpExecutionTF,1);
   const double h1 = iHigh(_Symbol,InpExecutionTF,1);
   const double l1 = iLow(_Symbol,InpExecutionTF,1);
   const double sweepTol = MathMax(1,InpWickSweepMinPoints) * _Point;

   bool hasSweep = false;
   if(zone.bullish)
     {
      if(c1 <= structureLevel)
        {
         zone.flowState = FLOW_IDLE;
         return false;
        }
      hasSweep = (l1 < (structureLevel - sweepTol));
     }
   else
     {
      if(c1 >= structureLevel)
        {
         zone.flowState = FLOW_IDLE;
         return false;
        }
      hasSweep = (h1 > (structureLevel + sweepTol));
     }

   if(!hasSweep)
      return false;

   zone.flowState = FLOW_LIQUIDITY_SWEEP;
   confidence += 20.0;
   stateTag += ">SWEEP";

   const bool fvgAligned = (structureLevel >= zone.lower && structureLevel <= zone.upper);
   if(!fvgAligned)
      return false;

   const double tol = MathMax(0,GetAdaptiveTriggerBufferPoints()) * _Point;
   zone.fvgRespected = zone.bullish ?
                       (l1 <= (zone.upper + tol) && c1 >= (zone.lower - tol)) :
                       (h1 >= (zone.lower - tol) && c1 <= (zone.upper + tol));
   zone.fvgDisrespected = zone.bullish ?
                          (c1 < (zone.lower - tol)) :
                          (c1 > (zone.upper + tol));

   confidence += 15.0;
   if(zone.fvgRespected)
      confidence += 10.0;
   if(zone.fvgDisrespected)
      confidence -= 25.0;

   zone.flowState = FLOW_CONFIRMATION_STATE;
   stateTag += ">CONFIRM";

   bool bos = false;
   bool choch = false;
   DetectRecentBOSCHOCH(zone.bullish,bos,choch);
   zone.bosAligned = bos;
   zone.chochAligned = choch;
   if(choch)
     {
      confidence += 18.0;
      stateTag += ">CHOCH";
     }
   else if(bos)
     {
      confidence += 10.0;
      stateTag += ">BOS";
     }
   else
     {
      confidence -= 10.0;
      stateTag += ">NOBOS";
      if(InpUseSupervisorPhase3 && InpSupervisorRequireBosOrChochFlow)
         return false;
     }

   const double mid = (zone.lower + zone.upper) * 0.5;
   int hits = 0;
   bool hasPriceTrigger = false;

   if(zone.bullish)
     {
      if(InpTriggerLowerTouch && CrossedBullLevel(g_prevBid,bid,zone.lower,tol))
        {
         hits++;
         hasPriceTrigger = true;
        }
      if(InpTriggerMidTouch && CrossedBullLevel(g_prevBid,bid,mid,tol))
        {
         hits++;
         hasPriceTrigger = true;
        }
      if(InpTriggerUpperTouch && CrossedBullLevel(g_prevBid,bid,zone.upper,tol))
        {
         hits++;
         hasPriceTrigger = true;
        }
     }
   else
     {
      if(InpTriggerLowerTouch && CrossedBearLevel(g_prevAsk,ask,zone.lower,tol))
        {
         hits++;
         hasPriceTrigger = true;
        }
      if(InpTriggerMidTouch && CrossedBearLevel(g_prevAsk,ask,mid,tol))
        {
         hits++;
         hasPriceTrigger = true;
        }
      if(InpTriggerUpperTouch && CrossedBearLevel(g_prevAsk,ask,zone.upper,tol))
        {
         hits++;
         hasPriceTrigger = true;
        }
     }

   if(!hasPriceTrigger)
      return false;

   if(InpTriggerRejectionCandle)
     {
      const bool rej = zone.bullish ?
                       BullRejectionAtLevel(structureLevel,tol) :
                       BearRejectionAtLevel(structureLevel,tol);
      if(rej)
         hits++;
     }

   if(InpTriggerMomentumBreak)
     {
      const double cNow = iClose(_Symbol,InpExecutionTF,1);
      const bool momentum = zone.bullish ?
                            (cNow > iHigh(_Symbol,InpExecutionTF,2)) :
                            (cNow < iLow(_Symbol,InpExecutionTF,2));
      if(momentum)
         hits++;
     }

   const int requiredHits = GetSupervisorPhase3RequiredHits(GetEffectiveMinTriggerHits());
   if(hits < requiredHits)
      return false;

   const datetime currBar = iTime(_Symbol,InpExecutionTF,0);
   if(currBar <= 0)
      return false;

   if(zone.gateBarTime != currBar)
     {
      zone.gateBarTime = currBar;
      zone.gateTicks = 0;
     }

   zone.gateTicks++;
   const int tickDelay = GetAdaptiveTriggerTickDelay();
   const int execTick = MathMax(MathMax(1,InpTriggerExecuteTick),tickDelay + 1);

   if(zone.gateTicks <= tickDelay)
      return false;
   if(zone.gateTicks != execTick)
      return false;

   if(zone.bullish && bid <= (structureLevel + tol))
      return false;
   if(!zone.bullish && ask >= (structureLevel - tol))
      return false;

   const double spreadPts = (ask - bid) / _Point;
   const int maxSpreadPts = GetEffectiveMaxSpreadPoints();
   if(maxSpreadPts > 0 && spreadPts > maxSpreadPts)
      return false;

   if(InpTriggerBlockOpposingImbalance && HasOpposingImbalanceNow(zone.bullish))
      return false;

   if(InpUseSupervisorPhase3)
     {
      const int regime = GetCurrentMarketRegime();
      if(regime == REGIME_RANGE)
        {
         confidence -= 6.0;
         stateTag += ">RNG";
         if(!zone.fvgRespected)
            return false;
        }
      else if(regime == REGIME_HIGHVOL)
        {
         confidence -= 8.0;
         stateTag += ">HV";
        }
      else
         stateTag += ">TRD";
     }

   zone.flowState = FLOW_EXECUTION_STATE;
   zone.confidence = MathMax(0.0,MathMin(100.0,confidence));

   if(zone.confidence < GetAdaptiveExecutionMinConfidence())
      return false;

   stateTag += ">EXEC";
   return true;
  }

bool ShouldSuspendPositionNow(const long pType,string &reason)
  {
   reason = "";
   if(!InpUseInstitutionalStateModel)
      return false;

   const bool bullishPos = (pType == POSITION_TYPE_BUY);
   if(!bullishPos && pType != POSITION_TYPE_SELL)
      return false;

   if(InpUseTransitionSuspendClose)
     {
      if(bullishPos)
        {
         double lastLH = 0.0, lastHH = 0.0, lastLL = 0.0, prevHL = 0.0;
         int lhShift = -1;
         if(GetBearTransitionAndPullback(lastLH,lastHH,lastLL,prevHL,lhShift))
           {
            reason = "market transitioned bearish";
            return true;
           }
        }
      else
        {
         double lastHL = 0.0, prevHL = 0.0, lastHH = 0.0, prevHH = 0.0;
         int hlShift = -1;
         if(GetBullTrendAndPullback(lastHL,prevHL,lastHH,prevHH,hlShift))
           {
            reason = "market transitioned bullish";
            return true;
           }
        }
     }

   SwingPoint swings[];
   if(BuildRecentSwings(swings,MathMax(80,InpPatternLookbackBars * 5),2))
     {
      const int n = ArraySize(swings);
      const SwingPoint s = swings[n - 1];

      if(n >= 2)
        {
         const SwingPoint p = swings[n - 2];
         const bool hasBearLL = ((!s.isHigh && s.label == SWING_LL) || (!p.isHigh && p.label == SWING_LL));
         const bool hasBearLH = ((s.isHigh && s.label == SWING_LH) || (p.isHigh && p.label == SWING_LH));
         const bool hasBullHH = ((s.isHigh && s.label == SWING_HH) || (p.isHigh && p.label == SWING_HH));
         const bool hasBullHL = ((!s.isHigh && s.label == SWING_HL) || (!p.isHigh && p.label == SWING_HL));

         if(bullishPos && hasBearLL && hasBearLH)
           {
            reason = "bearish structure shift (LH+LL)";
            return true;
           }
         if(!bullishPos && hasBullHH && hasBullHL)
           {
            reason = "bullish structure shift (HH+HL)";
            return true;
           }
        }

      if(bullishPos && !s.isHigh && s.label == SWING_LL)
        {
         reason = "opposite LL formed";
         return true;
        }
      if(!bullishPos && s.isHigh && s.label == SWING_HH)
        {
         reason = "opposite HH formed";
         return true;
        }
     }

   if(InpUseOppositeFVGSuspendClose)
     {
      const int limit = MathMax(2,InpOppositeFVGInvalidationCount);
      if(limit > 0 && CountOppositeFVGs(bullishPos) >= limit)
        {
         reason = "multiple opposite FVGs detected";
         return true;
        }
     }

   return false;
  }

int FindPositionManageStateIndex(const ulong ticket,const bool create)
  {
   for(int i = 0; i < ArraySize(g_posManage); i++)
     {
      if(g_posManage[i].ticket == ticket)
         return i;
     }

   if(!create)
      return -1;

   const int n = ArraySize(g_posManage);
   ArrayResize(g_posManage,n+1);
   g_posManage[n].ticket = ticket;
   g_posManage[n].peakProfitPts = 0.0;
   g_posManage[n].partialDone = false;
   g_posManage[n].rr1Done = false;
   return n;
  }

void PrunePositionManageState()
  {
   for(int i = ArraySize(g_posManage) - 1; i >= 0; i--)
     {
      const ulong ticket = g_posManage[i].ticket;
      bool found = false;

      for(int p = PositionsTotal() - 1; p >= 0; p--)
        {
         const ulong t = PositionGetTicket(p);
         if(t == 0 || !PositionSelectByTicket(t))
            continue;
         if(t != ticket)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic)
            continue;
         found = true;
         break;
        }

      if(found)
         continue;

      const int last = ArraySize(g_posManage) - 1;
      if(i < last)
         g_posManage[i] = g_posManage[last];
      ArrayResize(g_posManage,last);
     }
  }

double GetMagicFloatingProfit()
  {
   double sum = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;

      sum += PositionGetDouble(POSITION_PROFIT);
     }
   return sum;
  }

bool CloseMagicPositionWithReason(const ulong ticket,const string reason,const double profitPts,const double profitUsd,const int ageBars)
  {
   if(g_trade.PositionClose(ticket))
     {
      PrintFormat("ForceX close (%I64u): %s | pts=%.1f usd=%.2f ageBars=%d",
                  ticket,reason,profitPts,profitUsd,ageBars);
      return true;
     }

   PrintFormat("ForceX close FAILED (%I64u): %s | pts=%.1f usd=%.2f ageBars=%d | ret=%d %s",
               ticket,reason,profitPts,profitUsd,ageBars,
               (int)g_trade.ResultRetcode(),g_trade.ResultRetcodeDescription());
   return false;
  }

bool CloseMagicPositionPartialWithReason(const ulong ticket,const double volume,const string reason,const double profitPts,const double profitUsd,const int ageBars)
  {
   if(g_trade.PositionClosePartial(ticket,volume))
     {
      PrintFormat("ForceX partial close (%I64u): %s | vol=%.2f pts=%.1f usd=%.2f ageBars=%d",
                  ticket,reason,volume,profitPts,profitUsd,ageBars);
      return true;
     }

   PrintFormat("ForceX partial close FAILED (%I64u): %s | vol=%.2f pts=%.1f usd=%.2f ageBars=%d | ret=%d %s",
               ticket,reason,volume,profitPts,profitUsd,ageBars,
               (int)g_trade.ResultRetcode(),g_trade.ResultRetcodeDescription());
   return false;
  }

void CloseAllMagicPositionsByUSD(const string reason)
  {
   const double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   const int barSeconds = PeriodSeconds(InpExecutionTF);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      if(IsManualSLTPProtectedPosition())
         continue;

      const long pType = PositionGetInteger(POSITION_TYPE);
      const double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      const double posProfitMoney = PositionGetDouble(POSITION_PROFIT);
      const datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
      int ageBars = 0;
      if(barSeconds > 0 && posTime > 0)
         ageBars = (int)((TimeCurrent() - posTime) / barSeconds);
      const double profitPts = (pType == POSITION_TYPE_BUY) ? ((bid - openPrice) / _Point) : ((openPrice - ask) / _Point);

      CloseMagicPositionWithReason(ticket,"basket USD sweep: " + reason,profitPts,posProfitMoney,ageBars);
     }

   PrintFormat("ForceX basket USD sweep executed: %s",reason);
  }

bool ApplyUSDBasketSweepExit()
  {
   if(!InpUseUSDBasketSweep)
      return false;
   if(HasProtectedManualPositionOpen())
      return false;

   const double floating = GetMagicFloatingProfit();

   if(InpUSDBasketTakeProfit > 0.0 && floating >= InpUSDBasketTakeProfit)
     {
      CloseAllMagicPositionsByUSD("basket take profit $" + DoubleToString(floating,2));
      return true;
     }

   if(InpUSDBasketLossCut > 0.0 && floating <= -InpUSDBasketLossCut)
     {
      CloseAllMagicPositionsByUSD("basket loss cut $" + DoubleToString(floating,2));
      return true;
     }

   return false;
  }

void ManageOpenPositions()
  {
   const double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return;

   if(ApplyUSDBasketSweepExit())
      return;

   PrunePositionManageState();

   const int beTriggerPts = GetEffectiveBreakEvenTriggerPoints();
   const int beOffsetPts = GetEffectiveBreakEvenOffsetPoints();
   const bool useTrail = GetEffectiveUseTrailingStop();
   const int trailStartPts = GetEffectiveTrailingStartPoints();
   const int trailDistPts = GetEffectiveTrailingDistancePoints();
   const int firstMoveBePts = MathMax(MathMax(1,InpFirstMoveBreakEvenTriggerPoints),MathMax(1,InpFirstMoveBreakEvenMinPoints));
   const int trailAssistFloor = MathMax(1,InpFirstMoveTrailAssistMinPoints);
   const int trailStartEffective = InpFirstMoveTrailAssist ?
                                  MathMax(trailAssistFloor,MathMin(trailStartPts,MathMax(firstMoveBePts,trailAssistFloor))) :
                                  trailStartPts;
   const int scalpMaxBars = GetEffectiveMaxPositionBars();
   const bool useRR1 = InpUseRR1PartialAndBE;
   const double rr1PartialPct = MathMax(0.0,MathMin(95.0,InpRR1PartialClosePct)) / 100.0;
   const int rr1OffsetPts = MathMax(0,InpRR1BEOffsetPoints);
   const int barSeconds = PeriodSeconds(InpExecutionTF);
   const bool crash900Profile = IsCrash900ProfileActive();
   const int crash900MaxBars = MathMax(1,InpCrash900MaxPositionBars);

   const int stopLevelPts = (int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   const int freezeLevelPts = (int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   const int minLevelPts = MathMax(MathMax(stopLevelPts,freezeLevelPts),1);
   const double minDist = minLevelPts * _Point;
   const double atrPtsNow = MathMax(1.0,ComputeATRPoints(MathMax(6,InpSupervisorP4ATRPeriod)));
   const double o1Now = iOpen(_Symbol,InpExecutionTF,1);
   const double c1Now = iClose(_Symbol,InpExecutionTF,1);
   const double barRangePtsNow = MathMax(0.0,GetCurrentRangePoints(1));

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;

      const long pType = PositionGetInteger(POSITION_TYPE);
      const double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      const double tp = PositionGetDouble(POSITION_TP);
      const double posProfitMoney = PositionGetDouble(POSITION_PROFIT);
      const datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
      const bool manualProtected = IsManualSLTPProtectedPosition();
      const bool hasSetSLTP = (sl > 0.0 || tp > 0.0);
      const bool skipSoftCloses = (InpRespectSetSLTPForSoftCloses && hasSetSLTP);
      string suspendReason = "";
      int ageBars = 0;
      if(barSeconds > 0 && posTime > 0)
         ageBars = (int)((TimeCurrent() - posTime) / barSeconds);

      const double profitPts = (pType == POSITION_TYPE_BUY) ?
                               ((bid - openPrice) / _Point) :
                               ((openPrice - ask) / _Point);

      if(manualProtected)
         continue;

      if(crash900Profile)
        {
         if(InpUseUSDPerTradeSweep)
           {
            const bool hasTpCrash = (tp > 0.0);
            if(!hasTpCrash || InpUseUSDPerTradeSweepWithTP)
              {
               if(InpUSDTakeProfitPerTrade > 0.0 && posProfitMoney >= InpUSDTakeProfitPerTrade)
                 {
                  if(CloseMagicPositionWithReason(ticket,
                                                  StringFormat("crash900 per-trade USD take profit %.2f >= %.2f",
                                                               posProfitMoney,InpUSDTakeProfitPerTrade),
                                                  0.0,posProfitMoney,ageBars))
                     continue;
                 }
               if(InpUSDLossCutPerTrade > 0.0 && posProfitMoney <= -InpUSDLossCutPerTrade)
                 {
                  if(CloseMagicPositionWithReason(ticket,
                                                  StringFormat("crash900 per-trade USD loss cut %.2f <= -%.2f",
                                                               posProfitMoney,InpUSDLossCutPerTrade),
                                                  0.0,posProfitMoney,ageBars))
                     continue;
                 }
              }
           }

         if(ageBars >= crash900MaxBars)
           {
            if(CloseMagicPositionWithReason(ticket,
                                            StringFormat("crash900 max-bars exit age=%d>= %d",
                                                         ageBars,crash900MaxBars),
                                            profitPts,posProfitMoney,ageBars))
               continue;
           }

         continue;
        }

      // Highest-priority KUTMilz exit: close immediately on opposite candle color.
      if(InpUseKUTMilzCleanSetupOnly && InpKUTMilzExitOnOppositeCandle)
        {
         const bool oppositeClose = ((pType == POSITION_TYPE_BUY && c1Now < o1Now) ||
                                     (pType == POSITION_TYPE_SELL && c1Now > o1Now));
         if(oppositeClose)
           {
            if(CloseMagicPositionWithReason(ticket,
                                            StringFormat("KUTMilz opposite candle close o=%.5f c=%.5f",
                                                         o1Now,c1Now),
                                            profitPts,posProfitMoney,ageBars))
               continue;
           }
        }

      if(!skipSoftCloses && InpUseInstitutionalSuspendClose && ShouldSuspendPositionNow(pType,suspendReason))
        {
         CloseMagicPositionWithReason(ticket,"institutional suspend: " + suspendReason,0.0,posProfitMoney,ageBars);
         continue;
        }

      if(!skipSoftCloses && InpUseOppositeStrongCandleClose && InpUseV75DualSMCExecution && IsV75ProfileActive())
        {
         const double o1 = iOpen(_Symbol,InpExecutionTF,1);
         const double c1 = iClose(_Symbol,InpExecutionTF,1);
         const double h1 = iHigh(_Symbol,InpExecutionTF,1);
         const double l1 = iLow(_Symbol,InpExecutionTF,1);
         const double range1 = MathMax(h1 - l1,_Point);
         const double bodyPct = 100.0 * (MathAbs(c1 - o1) / range1);
         const bool oppositeStrong = (bodyPct >= MathMax(1.0,InpV75InvalidationBodyPct)) &&
                                     ((pType == POSITION_TYPE_BUY && c1 < o1) ||
                                      (pType == POSITION_TYPE_SELL && c1 > o1));
         if(oppositeStrong)
           {
            CloseMagicPositionWithReason(ticket,
                                         StringFormat("opposite strong candle body=%.1f%%>=%.1f%%",
                                                      bodyPct,MathMax(1.0,InpV75InvalidationBodyPct)),
                                         0.0,posProfitMoney,ageBars);
            continue;
           }
        }

      if(!skipSoftCloses && InpUseUSDPerTradeSweep)
        {
         const bool hasTp = (tp > 0.0);
         if(!hasTp || InpUseUSDPerTradeSweepWithTP)
           {
            if(InpUSDTakeProfitPerTrade > 0.0 && posProfitMoney >= InpUSDTakeProfitPerTrade)
              {
               CloseMagicPositionWithReason(ticket,
                                            StringFormat("per-trade USD take profit %.2f >= %.2f",
                                                         posProfitMoney,InpUSDTakeProfitPerTrade),
                                            0.0,posProfitMoney,ageBars);
               continue;
              }
            if(InpUSDLossCutPerTrade > 0.0 && posProfitMoney <= -InpUSDLossCutPerTrade)
              {
               CloseMagicPositionWithReason(ticket,
                                            StringFormat("per-trade USD loss cut %.2f <= -%.2f",
                                                         posProfitMoney,InpUSDLossCutPerTrade),
                                            0.0,posProfitMoney,ageBars);
               continue;
              }
          }
        }

      if(!skipSoftCloses && InpUseNoProgressExit)
        {
         const int barsLimit = MathMax(1,InpNoProgressExitBars);
         const double minProgress = MathMax(0.0,InpNoProgressMinProgressPts);
         if(ageBars >= barsLimit && profitPts < minProgress)
           {
            if(CloseMagicPositionWithReason(ticket,
                                            StringFormat("no-progress exit age=%d>= %d progress=%.1f<%.1f",
                                                         ageBars,barsLimit,profitPts,minProgress),
                                            profitPts,posProfitMoney,ageBars))
               continue;
           }
        }

      if(!skipSoftCloses && InpUseTimeStopExit)
        {
         const int softBars = MathMax(0,InpTimeStopBars);
         const int hardBars = MathMax(softBars,InpTimeStopHardLossBars);
         const double minProgress = MathMax(0.0,InpTimeStopMinProgressPts);

         if(softBars > 0 && ageBars >= softBars && profitPts < minProgress)
           {
            if(CloseMagicPositionWithReason(ticket,
                                            StringFormat("time-stop soft age=%d>= %d progress=%.1f<%.1f",
                                                         ageBars,softBars,profitPts,minProgress),
                                            profitPts,posProfitMoney,ageBars))
               continue;
           }

         if(hardBars > 0 && ageBars >= hardBars && profitPts <= 0.0)
           {
            if(CloseMagicPositionWithReason(ticket,
                                            StringFormat("time-stop hard age=%d>= %d progress=%.1f<=0",
                                                         ageBars,hardBars,profitPts),
                                            profitPts,posProfitMoney,ageBars))
               continue;
           }
        }

      const int mIdx = FindPositionManageStateIndex(ticket,true);
      if(mIdx >= 0 && profitPts > g_posManage[mIdx].peakProfitPts)
         g_posManage[mIdx].peakProfitPts = profitPts;

      const double riskPtsFromSL = (sl > 0.0) ? (MathAbs(openPrice - sl) / _Point) : 0.0;
      const double rNow = g_manageEngine.ComputeR(profitPts,MathMax(1.0,riskPtsFromSL));

      if(!skipSoftCloses &&
         g_manageEngine.ShouldTimeExit(ageBars,MathMax(0,InpTimeStopBars),profitPts,MathMax(0.0,InpTimeStopMinProgressPts)))
        {
         if(CloseMagicPositionWithReason(ticket,
                                         StringFormat("manage time-exit age=%d r=%.2f progress=%.1f",
                                                      ageBars,rNow,profitPts),
                                         profitPts,posProfitMoney,ageBars))
            continue;
        }

      if(!skipSoftCloses &&
         g_manageEngine.ShouldVolatilityExit((pType == POSITION_TYPE_BUY),
                                             o1Now,
                                             c1Now,
                                             barRangePtsNow,
                                             atrPtsNow,
                                             MathMax(1.0,InpVolatilityBurstAtrMult)))
        {
         if(CloseMagicPositionWithReason(ticket,
                                         StringFormat("manage volatility-exit range=%.1f ATR=%.1f",
                                                      barRangePtsNow,atrPtsNow),
                                         profitPts,posProfitMoney,ageBars))
            continue;
        }

      if(!skipSoftCloses && mIdx >= 0 && riskPtsFromSL >= 1.0 && g_manageEngine.ShouldPartialClose(rNow,2.0) && !g_posManage[mIdx].partialDone)
        {
         const double posVol = PositionGetDouble(POSITION_VOLUME);
         const double vMin = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
         const double vStep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
         double closeVol = posVol * 0.50;
         if(vStep > 0.0)
            closeVol = MathFloor(closeVol / vStep) * vStep;
         closeVol = NormalizeDouble(closeVol,2);
         if(closeVol >= vMin && (posVol - closeVol) >= vMin)
           {
            if(CloseMagicPositionPartialWithReason(ticket,
                                                   closeVol,
                                                   StringFormat("2R partial close | R=%.2f",rNow),
                                                   profitPts,posProfitMoney,ageBars))
              {
               g_posManage[mIdx].partialDone = true;
              }
           }
         else
            g_posManage[mIdx].partialDone = true;
        }

      if(riskPtsFromSL >= 1.0 && g_manageEngine.ShouldMoveBreakEven(rNow,1.0))
        {
         double beSL = 0.0;
         bool beModify = false;
         if(pType == POSITION_TYPE_BUY)
           {
            beSL = openPrice;
            if((sl == 0.0 || sl < beSL) && (bid - beSL) > minDist)
               beModify = true;
           }
         else if(pType == POSITION_TYPE_SELL)
           {
            beSL = openPrice;
            if((sl == 0.0 || sl > beSL) && (beSL - ask) > minDist && beSL > 0.0)
               beModify = true;
           }
         if(beModify)
            g_trade.PositionModify(ticket,NormalizeDouble(beSL,_Digits),tp);
        }

      if(useRR1 && !skipSoftCloses && mIdx >= 0 && riskPtsFromSL >= 1.0 && profitPts >= riskPtsFromSL)
        {
         double rr1SL = sl;
         bool rr1Modify = false;

         if(pType == POSITION_TYPE_BUY)
           {
            const double beSL = openPrice + rr1OffsetPts * _Point;
            if((sl == 0.0 || sl < beSL) && (bid - beSL) > minDist)
              {
               rr1SL = beSL;
               rr1Modify = true;
              }
           }
         else if(pType == POSITION_TYPE_SELL)
           {
            const double beSL = openPrice - rr1OffsetPts * _Point;
            if((sl == 0.0 || sl > beSL) && (beSL - ask) > minDist && beSL > 0.0)
              {
               rr1SL = beSL;
               rr1Modify = true;
              }
           }

         if(rr1Modify)
            g_trade.PositionModify(ticket,NormalizeDouble(rr1SL,_Digits),tp);

         if(!g_posManage[mIdx].rr1Done && rr1PartialPct > 0.0)
           {
            const double posVol = PositionGetDouble(POSITION_VOLUME);
            const double vMin = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
            const double vStep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
            double closeVol = posVol * rr1PartialPct;
            if(vStep > 0.0)
               closeVol = MathFloor(closeVol / vStep) * vStep;
            closeVol = NormalizeDouble(closeVol,2);

            if(closeVol >= vMin && (posVol - closeVol) >= vMin)
              {
               if(CloseMagicPositionPartialWithReason(ticket,closeVol,
                                                      StringFormat("RR1 partial + BE (risk=%.1fpts, profit=%.1fpts)",
                                                                   riskPtsFromSL,profitPts),
                                                      profitPts,posProfitMoney,ageBars))
                 {
                  g_posManage[mIdx].rr1Done = true;
                  continue;
                 }
              }
            else
               g_posManage[mIdx].rr1Done = true;
           }
        }

      if(!skipSoftCloses && mIdx >= 0 && InpUseInstitutionalStateModel && g_posManage[mIdx].peakProfitPts > 0.0 && posProfitMoney >= 0.0)
        {
         const double retracePct = 100.0 * (g_posManage[mIdx].peakProfitPts - profitPts) / g_posManage[mIdx].peakProfitPts;

         if(!g_posManage[mIdx].partialDone &&
            g_posManage[mIdx].peakProfitPts >= MathMax(1,InpPartialProtectMinPeakPts) &&
            retracePct >= MathMax(0.0,InpPartialProtectRetracePct))
           {
            const double posVol = PositionGetDouble(POSITION_VOLUME);
            const double vMin = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
            const double vStep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
            double closeVol = (vStep > 0.0) ? (MathFloor((posVol * 0.5) / vStep) * vStep) : (posVol * 0.5);

            if(vStep > 0.0)
               closeVol = NormalizeDouble(closeVol,2);

            if(closeVol >= vMin && (posVol - closeVol) >= vMin)
              {
               if(CloseMagicPositionPartialWithReason(ticket,closeVol,
                                                      StringFormat("partial protect retrace %.1f%%>=%.1f%% peak=%.1f",
                                                                   retracePct,MathMax(0.0,InpPartialProtectRetracePct),
                                                                   g_posManage[mIdx].peakProfitPts),
                                                      profitPts,posProfitMoney,ageBars))
                 {
                  g_posManage[mIdx].partialDone = true;
                  continue;
                 }
              }
           }

         if(g_posManage[mIdx].partialDone &&
            retracePct >= MathMax(0.0,InpFinalProtectRetracePct) &&
            posProfitMoney >= 0.0)
           {
            CloseMagicPositionWithReason(ticket,
                                         StringFormat("final protect retrace %.1f%%>=%.1f%%",
                                                      retracePct,MathMax(0.0,InpFinalProtectRetracePct)),
                                         profitPts,posProfitMoney,ageBars);
            continue;
           }
        }

      if(pType == POSITION_TYPE_BUY)
        {
         if(!skipSoftCloses && scalpMaxBars > 0)
           {
            if((ageBars >= scalpMaxBars && profitPts >= 0.0) ||
               (ageBars >= scalpMaxBars * 2 && profitPts < 0.0))
              {
               CloseMagicPositionWithReason(ticket,
                                            StringFormat("scalp max bars close age=%d max=%d profitPts=%.1f",
                                                         ageBars,scalpMaxBars,profitPts),
                                            profitPts,posProfitMoney,ageBars);
               continue;
              }
           }

         double newSL = sl;
         bool shouldModify = false;

         if(InpUseFirstMoveBreakEven && profitPts >= firstMoveBePts)
           {
            const double firstBeSL = openPrice;
            if((sl == 0.0 || sl < (firstBeSL - (_Point * 0.2))) && (bid - firstBeSL) > minDist)
              {
               newSL = firstBeSL;
               shouldModify = true;
              }
           }

         if(beTriggerPts > 0 && profitPts >= beTriggerPts)
           {
            const double beSL = openPrice + beOffsetPts * _Point;
            if((newSL == 0.0 || newSL < beSL) && (bid - beSL) > minDist)
              {
               newSL = beSL;
               shouldModify = true;
              }
           }

         if(useTrail && trailDistPts > 0 && profitPts >= trailStartEffective)
           {
            double trailSL = bid - trailDistPts * _Point;
            if((bid - trailSL) < minDist)
               trailSL = bid - minDist;

            if((newSL == 0.0 || trailSL > newSL) && trailSL > 0.0 && trailSL < bid)
              {
               newSL = trailSL;
               shouldModify = true;
              }
           }

         if(shouldModify && (sl == 0.0 || MathAbs(newSL - sl) > _Point))
            g_trade.PositionModify(ticket,NormalizeDouble(newSL,_Digits),tp);
        }
      else if(pType == POSITION_TYPE_SELL)
        {
         if(!skipSoftCloses && scalpMaxBars > 0)
           {
            if((ageBars >= scalpMaxBars && profitPts >= 0.0) ||
               (ageBars >= scalpMaxBars * 2 && profitPts < 0.0))
              {
               CloseMagicPositionWithReason(ticket,
                                            StringFormat("scalp max bars close age=%d max=%d profitPts=%.1f",
                                                         ageBars,scalpMaxBars,profitPts),
                                            profitPts,posProfitMoney,ageBars);
               continue;
              }
           }

         double newSL = sl;
         bool shouldModify = false;

         if(InpUseFirstMoveBreakEven && profitPts >= firstMoveBePts)
           {
            const double firstBeSL = openPrice;
            if((sl == 0.0 || sl > (firstBeSL + (_Point * 0.2))) && (firstBeSL - ask) > minDist && firstBeSL > 0.0)
              {
               newSL = firstBeSL;
               shouldModify = true;
              }
           }

         if(beTriggerPts > 0 && profitPts >= beTriggerPts)
           {
            const double beSL = openPrice - beOffsetPts * _Point;
            if((newSL == 0.0 || newSL > beSL) && (beSL - ask) > minDist && beSL > 0.0)
              {
               newSL = beSL;
               shouldModify = true;
              }
           }

         if(useTrail && trailDistPts > 0 && profitPts >= trailStartEffective)
           {
            double trailSL = ask + trailDistPts * _Point;
            if((trailSL - ask) < minDist)
               trailSL = ask + minDist;

            if((newSL == 0.0 || trailSL < newSL) && trailSL > ask)
              {
               newSL = trailSL;
               shouldModify = true;
              }
           }

         if(shouldModify && (sl == 0.0 || MathAbs(newSL - sl) > _Point))
            g_trade.PositionModify(ticket,NormalizeDouble(newSL,_Digits),tp);
        }
     }
  }

ENUM_BIAS DetectSimpleBias(const ENUM_TIMEFRAMES tf)
  {
   const ENUM_TIMEFRAMES tfUse = (InpSimpleModeNoGates && InpSimpleOneTimeframe) ? InpExecutionTF : tf;
   if(Bars(_Symbol,tfUse) < 20)
      return BIAS_NEUTRAL;

   const double h1 = iHigh(_Symbol,tfUse,1);
   const double h2 = iHigh(_Symbol,tfUse,2);
   const double l1 = iLow(_Symbol,tfUse,1);
   const double l2 = iLow(_Symbol,tfUse,2);
   const double c1 = iClose(_Symbol,tfUse,1);
   const double c2 = iClose(_Symbol,tfUse,2);

   if(h1 > h2 && l1 > l2 && c1 > c2)
      return BIAS_BULL;

   if(h1 < h2 && l1 < l2 && c1 < c2)
      return BIAS_BEAR;

   return BIAS_NEUTRAL;
  }

bool BiasAllowsDirection(const bool bullish)
  {
   if(InpSimpleModeNoGates)
      return true;

   if(!InpUseBiasFilter)
      return true;

   const ENUM_BIAS macroBias = DetectSimpleBias(InpMacroTF);
   const ENUM_BIAS internalBias = DetectSimpleBias(InpInternalTF);

   if(bullish)
      return (macroBias != BIAS_BEAR && internalBias != BIAS_BEAR);

   return (macroBias != BIAS_BULL && internalBias != BIAS_BULL);
  }

bool HasLiquiditySweep(const bool bullish)
  {
   if(!InpRequireLiquiditySweep)
      return true;

   const int bars = Bars(_Symbol,InpExecutionTF);
   if(bars < InpSweepLookbackBars + 5)
      return false;

   if(bullish)
     {
      const double sweptLow = iLow(_Symbol,InpExecutionTF,1);
      double refLow = DBL_MAX;

      for(int i = 2; i <= InpSweepLookbackBars + 1; i++)
         refLow = MathMin(refLow,iLow(_Symbol,InpExecutionTF,i));

      return (sweptLow < refLow);
     }

   const double sweptHigh = iHigh(_Symbol,InpExecutionTF,1);
   double refHigh = -DBL_MAX;

   for(int i = 2; i <= InpSweepLookbackBars + 1; i++)
      refHigh = MathMax(refHigh,iHigh(_Symbol,InpExecutionTF,i));

   return (sweptHigh > refHigh);
  }

bool ValidateOrderBlockConfluence(const bool bullish,const FVGZone &zone)
  {
   if(!InpRequireOBAlignment)
      return true;

   const int obShift = zone.anchorShift + 1;
   if(obShift < 1)
      return false;

   const double obOpen  = iOpen(_Symbol,InpExecutionTF,obShift);
   const double obClose = iClose(_Symbol,InpExecutionTF,obShift);
   const double obHigh  = iHigh(_Symbol,InpExecutionTF,obShift);
   const double obLow   = iLow(_Symbol,InpExecutionTF,obShift);

   if(bullish)
     {
      const bool oppositeCandle = (obClose < obOpen);
      const bool overlapsZone = (obLow <= zone.upper && obHigh >= zone.lower);
      return (oppositeCandle && overlapsZone);
     }

   const bool oppositeCandle = (obClose > obOpen);
   const bool overlapsZone = (obLow <= zone.upper && obHigh >= zone.lower);
   return (oppositeCandle && overlapsZone);
  }

bool ZoneOverlaps(const double aLow,const double aHigh,const double bLow,const double bHigh)
  {
   return (aLow <= bHigh && aHigh >= bLow);
  }

bool HasMTFOverlap(const FVGZone &zone)
  {
   if(InpSimpleModeNoGates || (InpSimpleOneTimeframe && InpSimpleModeNoGates))
      return true;

   if(!InpRequireMTFOverlap)
      return true;

   const int bars = Bars(_Symbol,InpFVGOverlapTF);
   if(bars < 20)
      return false;

   const int scan = MathMin(bars - 3,150);

   for(int i = 1; i <= scan; i++)
     {
      const double low0  = iLow(_Symbol,InpFVGOverlapTF,i);
      const double high0 = iHigh(_Symbol,InpFVGOverlapTF,i);
      const double low2  = iLow(_Symbol,InpFVGOverlapTF,i+2);
      const double high2 = iHigh(_Symbol,InpFVGOverlapTF,i+2);

      if(zone.bullish)
        {
         if(low0 <= high2)
            continue;

         const double zLow = high2;
         const double zHigh = low0;
         if(ZoneOverlaps(zone.lower,zone.upper,zLow,zHigh))
            return true;
        }
      else
        {
         if(low2 <= high0)
            continue;

         const double zLow = high0;
         const double zHigh = low2;
         if(ZoneOverlaps(zone.lower,zone.upper,zLow,zHigh))
            return true;
        }
     }

   return false;
  }

double ComputeZoneGapAtr(const FVGZone &zone)
  {
   const double atrPts = ComputeATRPoints(MathMax(2,InpSupervisorATRPeriod));
   if(atrPts <= 0.0)
      return 0.0;
   return zone.gapPoints / atrPts;
  }

bool DetectRecentBOSCHOCH(const bool bullish,bool &bosOut,bool &chochOut)
  {
   bosOut = false;
   chochOut = false;

   SwingPoint swings[];
   const int lookback = MathMax(80,InpStructureLookbackBars);
   if(!BuildRecentSwings(swings,lookback,2))
      return false;

   const int n = ArraySize(swings);
   if(n < 3)
      return false;

   int lastIdx = -1;
   int prevIdx = -1;
   for(int i = n - 1; i >= 0; i--)
     {
      if(bullish && swings[i].isHigh)
        {
         if(lastIdx < 0)
            lastIdx = i;
         else
           {
            prevIdx = i;
            break;
           }
        }
      if(!bullish && !swings[i].isHigh)
        {
         if(lastIdx < 0)
            lastIdx = i;
         else
           {
            prevIdx = i;
            break;
           }
        }
     }

   if(lastIdx < 0)
      return false;

   const int lbl = swings[lastIdx].label;
   const int prevLbl = (prevIdx >= 0) ? swings[prevIdx].label : SWING_NONE;

   if(bullish)
     {
      bosOut = (lbl == SWING_HH);
      chochOut = (lbl == SWING_HH && prevLbl == SWING_LH);
     }
   else
     {
      bosOut = (lbl == SWING_LL);
      chochOut = (lbl == SWING_LL && prevLbl == SWING_HL);
     }

   return true;
  }

bool IsFVGFakeConfirmed(const FVGZone &zone)
  {
   const double gapSize = zone.upper - zone.lower;
   if(gapSize <= 0.0)
      return false;

   const int bars = Bars(_Symbol,InpExecutionTF);
   if(bars < 3)
      return false;

   const int maxBars = MathMin(MathMax(1,InpSupervisorFakeConfirmBars),bars - 2);
   const double fillPctReq = MathMax(1.0,MathMin(100.0,InpSupervisorFakeFillPct));
   const double tol = MathMax(1,GetAdaptiveTriggerBufferPoints()) * _Point;

   for(int i = 1; i <= maxBars; i++)
     {
      const double o = iOpen(_Symbol,InpExecutionTF,i);
      const double c = iClose(_Symbol,InpExecutionTF,i);
      const double bodyLow = MathMin(o,c);
      const double bodyHigh = MathMax(o,c);

      const double ovLow = MathMax(bodyLow,zone.lower);
      const double ovHigh = MathMin(bodyHigh,zone.upper);
      const double ov = MathMax(0.0,ovHigh - ovLow);
      const double fillPct = (ov / gapSize) * 100.0;
      const bool fullBodyFill = (bodyLow <= zone.lower && bodyHigh >= zone.upper);
      const bool directionalBreak = zone.bullish ?
                                    (c < (zone.lower - tol)) :
                                    (c > (zone.upper + tol));

      // Prevent false fake-tagging from minor overlap; require directional invalidation close.
      if(directionalBreak && (fillPct >= fillPctReq || fullBodyFill))
         return true;
     }
   return false;
  }

int ComputeFVGQualityTier(FVGZone &zone)
  {
   zone.gapAtr = ComputeZoneGapAtr(zone);

   int ageBars = 0;
   const int sec = PeriodSeconds(InpExecutionTF);
   if(sec > 0 && zone.time1 > 0)
      ageBars = (int)MathMax(0,(TimeCurrent() - zone.time1) / sec);
   zone.ageBars = ageBars;

   const double atrPts = ComputeATRPoints(MathMax(2,InpSupervisorATRPeriod));
   const double mid = (zone.lower + zone.upper) * 0.5;
   double ref = zone.targetLiquidity;
   if(ref <= 0.0)
      ref = zone.structureLevel;
   if(ref <= 0.0)
      ref = mid;

   double proximityScore = 30.0;
   if(atrPts > 0.0)
     {
      const double distPts = MathAbs(mid - ref) / _Point;
      const double distAtr = distPts / atrPts;
      if(distAtr <= 1.0)
         proximityScore = 100.0;
      else if(distAtr <= 2.0)
         proximityScore = 70.0;
      else if(distAtr <= 3.0)
         proximityScore = 40.0;
      else
         proximityScore = 10.0;
     }

   const double rangePts = (iHigh(_Symbol,InpExecutionTF,1) - iLow(_Symbol,InpExecutionTF,1)) / _Point;
   double volScore = 50.0;
   if(atrPts > 0.0)
     {
      const double volMult = rangePts / atrPts;
      if(volMult >= 1.25)
         volScore = 100.0;
      else if(volMult >= 1.0)
         volScore = 70.0;
      else
         volScore = 40.0;
     }

   double ageScore = 10.0;
   if(ageBars <= 20)
      ageScore = 100.0;
   else if(ageBars <= 40)
      ageScore = 70.0;
   else if(ageBars <= 60)
      ageScore = 40.0;

   double gapScore = 0.0;
   if(zone.gapAtr > 0.0)
      gapScore = MathMin(100.0,(zone.gapAtr / 0.40) * 100.0);

   const double bodyScore = MathMax(0.0,MathMin(100.0,zone.bodyPct));
   zone.qualityScore = MathMax(0.0,MathMin(100.0,
                                            gapScore * 0.40 +
                                            bodyScore * 0.20 +
                                            ageScore * 0.15 +
                                            proximityScore * 0.15 +
                                            volScore * 0.10));

   zone.fakeConfirmed = IsFVGFakeConfirmed(zone);
   if(zone.fakeConfirmed)
     {
      zone.qualityTier = 0;
      return 0;
     }

   if(zone.gapAtr >= 0.40 && ageBars <= 20 && zone.qualityScore >= 80.0)
     {
      zone.qualityTier = 3;
      return 3;
     }
   if(zone.gapAtr >= 0.20 && ageBars <= 40 && zone.qualityScore >= 50.0)
     {
      zone.qualityTier = 2;
      return 2;
     }
   if(zone.gapAtr >= 0.10 && ageBars <= 60 && zone.qualityScore >= 25.0)
     {
      zone.qualityTier = 1;
      return 1;
     }

   zone.qualityTier = 0;
   return 0;
  }

double ComputeLiquidityTakeLikelihood(const FVGZone &zone,const bool bullish)
  {
   double score = 0.0;
   const double atrPts = ComputeATRPoints(MathMax(2,InpSupervisorATRPeriod));
   const double c1 = iClose(_Symbol,InpExecutionTF,1);
   const double h1 = iHigh(_Symbol,InpExecutionTF,1);
   const double l1 = iLow(_Symbol,InpExecutionTF,1);

   bool wickBreak = false;
   bool retest = false;
   if(bullish)
     {
      wickBreak = (l1 < zone.lower);
      retest = (wickBreak && c1 > zone.lower);
     }
   else
     {
      wickBreak = (h1 > zone.upper);
      retest = (wickBreak && c1 < zone.upper);
     }

   if(retest)
      score += 30.0;
   else if(wickBreak)
      score += 10.0;

   double ref = zone.targetLiquidity;
   if(ref <= 0.0)
      ref = zone.structureLevel;
   if(ref > 0.0 && atrPts > 0.0)
     {
      const double distPts = MathAbs(c1 - ref) / _Point;
      const double distAtr = distPts / atrPts;
      if(distAtr <= 0.25)
         score += 25.0;
      else if(distAtr <= 1.0)
         score += 15.0;
      else if(distAtr <= 3.0)
         score += 5.0;
     }

   if(atrPts > 0.0)
     {
      const double rangePts = (h1 - l1) / _Point;
      const double spike = rangePts / atrPts;
      if(spike > 2.0)
         score += 25.0;
      else if(spike >= 1.25)
         score += 10.0;
     }

   if(BiasAllowsDirection(bullish))
      score += 10.0;

  return MathMax(0.0,MathMin(100.0,score));
  }

int GetSupervisorP4SpreadMaxPoints()
  {
   if(IsV75ProfileActive())
      return MathMax(1,g_isV751s ? InpSupervisorP4SpreadMaxV751s : InpSupervisorP4SpreadMaxV75);
   return MathMax(1,GetEffectiveMaxSpreadPoints());
  }

double GetSupervisorP4VolSpikeThreshold()
  {
   if(IsV75ProfileActive())
      return MathMax(0.5,g_isV751s ? InpSupervisorP4VolSpikeAtrV751s : InpSupervisorP4VolSpikeAtrV75);
   return 3.0;
  }

bool DetectSupervisorP4KingCandle(const bool bullish,int &kingType,double &quality)
  {
   kingType = 0;
   quality = 0.0;
   if(Bars(_Symbol,InpExecutionTF) < 8)
      return false;

   const double atrPts = MathMax(1.0,ComputeATRPoints(MathMax(2,InpSupervisorP4ATRPeriod)));

   const double o1 = iOpen(_Symbol,InpExecutionTF,1);
   const double c1 = iClose(_Symbol,InpExecutionTF,1);
   const double h1 = iHigh(_Symbol,InpExecutionTF,1);
   const double l1 = iLow(_Symbol,InpExecutionTF,1);
   const double o2 = iOpen(_Symbol,InpExecutionTF,2);
   const double c2 = iClose(_Symbol,InpExecutionTF,2);
   const double h2 = iHigh(_Symbol,InpExecutionTF,2);
   const double l2 = iLow(_Symbol,InpExecutionTF,2);

   const double r1 = MathMax(h1 - l1,_Point);
   const double r2 = MathMax(h2 - l2,_Point);
   const double r1Pts = r1 / _Point;
   const double r2Pts = r2 / _Point;
   const double b1 = MathAbs(c1 - o1);
   const double b2 = MathAbs(c2 - o2);
   const double b1Pct = 100.0 * b1 / r1;
   const double b2Pct = 100.0 * b2 / r2;

   const double upW1 = h1 - MathMax(o1,c1);
   const double dnW1 = MathMin(o1,c1) - l1;
   const double upW2 = h2 - MathMax(o2,c2);
   const double dnW2 = MathMin(o2,c2) - l2;
   const double maxW1Pct = 100.0 * MathMax(upW1,dnW1) / r1;
   const double maxW2Pct = 100.0 * MathMax(upW2,dnW2) / r2;

   double bestQ = 0.0;
   int bestK = 0;

   // BE_King
   {
    const bool dir = bullish ? (c1 > o1 && c2 < o2) : (c1 < o1 && c2 > o2);
    const bool engulf = (MathMax(o1,c1) >= MathMax(o2,c2) && MathMin(o1,c1) <= MathMin(o2,c2));
    const bool bodyRatio = (b1 / MathMax(b2,_Point)) >= 1.20;
    const bool minAtr = (r1Pts / atrPts) >= 0.80;
    double closeInto = 0.0;
    const double prevTop = MathMax(o2,c2);
    const double prevBot = MathMin(o2,c2);
    const double prevSize = MathMax(prevTop - prevBot,_Point);
    if(bullish)
       closeInto = (c1 - prevTop) / prevSize;
    else
       closeInto = (prevBot - c1) / prevSize;
    if(dir && engulf && bodyRatio && minAtr && closeInto >= 0.70)
      {
       bestK = 1;
       bestQ = 74.0 + MathMin(20.0,(b1Pct - 60.0) * 0.4);
      }
   }

   // Doji_King (doji at bar 2, confirmation at bar 1)
   {
    const bool doji = (b2Pct <= 10.0) && ((r2Pts / atrPts) >= 0.70);
    const bool confirm = bullish ? (c1 > o1) : (c1 < o1);
    const bool confirmBody = (b1Pct >= 60.0);
    if(doji && confirm && confirmBody)
      {
       const double q = 66.0 + MathMin(18.0,(60.0 - MathMin(60.0,b2Pct)) * 0.2);
       if(q > bestQ)
         {
          bestQ = q;
          bestK = 2;
         }
      }
   }

   // DM_King
   {
    const bool dir = bullish ? (c1 > o1 && c2 > o2) : (c1 < o1 && c2 < o2);
    const bool maru = (b1Pct >= 80.0 && b2Pct >= 80.0);
    const bool lowWick = (maxW1Pct <= 5.0 && maxW2Pct <= 5.0);
    const bool rangeAtr = ((r1Pts + r2Pts) / atrPts) >= 1.50;
    if(dir && maru && lowWick && rangeAtr)
      {
       const double q = 82.0 + MathMin(14.0,((b1Pct + b2Pct) - 160.0) * 0.2);
       if(q > bestQ)
         {
          bestQ = q;
          bestK = 3;
         }
      }
   }

   // DR_BE_King
   {
    const bool doji = (b2Pct <= 10.0);
    const bool engulf = (MathMax(o1,c1) >= MathMax(o2,c2) && MathMin(o1,c1) <= MathMin(o2,c2));
    const bool dir = bullish ? (c1 > o1) : (c1 < o1);
    const bool bodyRatio = (b1 / MathMax(b2,_Point)) >= 1.10;
    if(doji && engulf && dir && bodyRatio)
      {
       const double q = 85.0 + MathMin(12.0,(b1Pct - 50.0) * 0.2);
       if(q > bestQ)
         {
          bestQ = q;
          bestK = 4;
         }
      }
   }

   if(bestK <= 0)
      return false;

   kingType = bestK;
   quality = MathMax(0.0,MathMin(100.0,bestQ));
   return true;
  }

bool DetectSupervisorP4Compression(const bool bullish,double &quality)
  {
   quality = 0.0;
   const int n = 6;
   if(Bars(_Symbol,InpExecutionTF) < n + 6)
      return false;

   const double atrPts = MathMax(1.0,ComputeATRPoints(MathMax(2,InpSupervisorP4ATRPeriod)));
   double maxHigh = -DBL_MAX;
   double minLow = DBL_MAX;
   double oldSum = 0.0;
   double newSum = 0.0;
   int oldCnt = 0;
   int newCnt = 0;
   int dirLegs = 0;
   int legs = 0;

   for(int i = n; i >= 1; i--)
     {
      const double h = iHigh(_Symbol,InpExecutionTF,i);
      const double l = iLow(_Symbol,InpExecutionTF,i);
      const double rPts = MathMax((h - l) / _Point,1.0);
      maxHigh = MathMax(maxHigh,h);
      minLow = MathMin(minLow,l);
      if(i > (n / 2))
        {
         oldSum += rPts;
         oldCnt++;
        }
      else
        {
         newSum += rPts;
         newCnt++;
        }
     }

   for(int i = n; i >= 2; i--)
     {
      const double prevHigh = iHigh(_Symbol,InpExecutionTF,i);
      const double prevLow = iLow(_Symbol,InpExecutionTF,i);
      const double curHigh = iHigh(_Symbol,InpExecutionTF,i - 1);
      const double curLow = iLow(_Symbol,InpExecutionTF,i - 1);
      bool dir = false;
      if(bullish)
         dir = (curHigh <= prevHigh && curLow <= prevLow);
      else
         dir = (curHigh >= prevHigh && curLow >= prevLow);
      if(dir)
         dirLegs++;
      legs++;
     }

   if(oldCnt <= 0 || newCnt <= 0 || legs <= 0)
      return false;

   const double oldAvg = oldSum / oldCnt;
   const double newAvg = newSum / newCnt;
   if(oldAvg <= 0.0)
      return false;

   const double reducePct = ((oldAvg - newAvg) / oldAvg) * 100.0;
   const double channelPts = (maxHigh - minLow) / _Point;
   const double body1 = MathAbs(iClose(_Symbol,InpExecutionTF,1) - iOpen(_Symbol,InpExecutionTF,1));
   const double rng1 = MathMax(iHigh(_Symbol,InpExecutionTF,1) - iLow(_Symbol,InpExecutionTF,1),_Point);
   const double body1Pct = body1 / rng1;

   if(reducePct < 15.0)
      return false;
   if(channelPts > (1.5 * atrPts))
      return false;
   if(body1Pct < 0.50)
      return false;
   if(dirLegs < MathMax(2,legs - 1))
      return false;

   quality = MathMax(0.0,MathMin(100.0,62.0 + MathMin(28.0,reducePct * 0.6)));
   return true;
  }

bool DetectSupervisorP4Flippy(const FVGZone &zone,const bool bullish,double &quality)
  {
   quality = 0.0;
   if(Bars(_Symbol,InpExecutionTF) < 8)
      return false;

   const double level = bullish ? zone.lower : zone.upper;
   const int minRangePts = MathMax(10,InpSupervisorP4FlippyMinRangePts);
   double bestPen = 0.0;
   int invalid = 0;

   for(int i = 1; i <= 3; i++)
     {
      const double o = iOpen(_Symbol,InpExecutionTF,i);
      const double c = iClose(_Symbol,InpExecutionTF,i);
      const double h = iHigh(_Symbol,InpExecutionTF,i);
      const double l = iLow(_Symbol,InpExecutionTF,i);
      const double rPts = MathMax((h - l) / _Point,1.0);
      if(rPts < minRangePts)
         continue;

      if(bullish)
        {
         const double pen = (level - l) / MathMax(h - l,_Point);
         if(l < level && c > level && pen >= 0.30)
            bestPen = MathMax(bestPen,pen);
         if(((level - c) / MathMax(h - l,_Point)) >= 0.25)
            invalid++;
        }
      else
        {
         const double pen = (h - level) / MathMax(h - l,_Point);
         if(h > level && c < level && pen >= 0.30)
            bestPen = MathMax(bestPen,pen);
         if(((c - level) / MathMax(h - l,_Point)) >= 0.25)
            invalid++;
        }
     }

   if(invalid >= 2 || bestPen <= 0.0)
      return false;

   quality = MathMax(0.0,MathMin(100.0,60.0 + bestPen * 80.0));
   return true;
  }

bool DetectSupervisorP4ThreeDrive(const bool bullish,double &quality)
  {
   quality = 0.0;
   SwingPoint swings[];
   if(!BuildRecentSwings(swings,MathMax(140,InpStructureLookbackBars),2))
      return false;

   const int n = ArraySize(swings);
   int idxNew = -1;
   int idxMid = -1;
   int idxOld = -1;
   for(int i = n - 1; i >= 0; i--)
     {
      const bool ok = bullish ? (!swings[i].isHigh) : swings[i].isHigh;
      if(!ok)
         continue;
      if(idxNew < 0)
         idxNew = i;
      else if(idxMid < 0)
         idxMid = i;
      else
        {
         idxOld = i;
         break;
        }
     }

   if(idxOld < 0 || idxMid < 0 || idxNew < 0)
      return false;

   const SwingPoint sOld = swings[idxOld];
   const SwingPoint sMid = swings[idxMid];
   const SwingPoint sNew = swings[idxNew];
   if(MathAbs(sOld.shift - sMid.shift) < 3 || MathAbs(sMid.shift - sNew.shift) < 3)
      return false;

   const double denom = (double)(sOld.shift - sNew.shift);
   if(MathAbs(denom) < 1.0)
      return false;
   const double t = (double)(sOld.shift - sMid.shift) / denom;
   const double expectedMid = sOld.price + t * (sNew.price - sOld.price);
   const double devPts = MathAbs(sMid.price - expectedMid) / _Point;
   if(devPts > MathMax(20,InpSupervisorP4ThreeDriveTolPts))
      return false;

   const double d1 = MathAbs(sMid.price - sOld.price);
   const double d2 = MathAbs(sNew.price - sMid.price);
   if(d1 <= _Point || d2 < (d1 * 1.10))
      return false;

   const double o1 = iOpen(_Symbol,InpExecutionTF,1);
   const double c1 = iClose(_Symbol,InpExecutionTF,1);
   const double h1 = iHigh(_Symbol,InpExecutionTF,1);
   const double l1 = iLow(_Symbol,InpExecutionTF,1);
   const double bodyPct = MathAbs(c1 - o1) / MathMax(h1 - l1,_Point);
   if(bodyPct < 0.50)
      return false;
   if(bullish && !(c1 > o1))
      return false;
   if(!bullish && !(c1 < o1))
      return false;

   quality = MathMax(0.0,MathMin(100.0,64.0 + MathMin(26.0,((d2 / d1) - 1.0) * 100.0)));
   return true;
  }

bool DetectSupervisorP4QM(const bool bullish,double &quality)
  {
   quality = 0.0;
   SwingPoint swings[];
   if(!BuildRecentSwings(swings,MathMax(160,InpStructureLookbackBars),2))
      return false;

   const int n = ArraySize(swings);
   const double c1 = iClose(_Symbol,InpExecutionTF,1);
   for(int i = n - 1; i >= 3; i--)
     {
      const SwingPoint s0 = swings[i];
      const SwingPoint s1 = swings[i-1];
      const SwingPoint s2 = swings[i-2];
      const SwingPoint s3 = swings[i-3];

      if(bullish)
        {
         if(!(s0.isHigh && !s1.isHigh && s2.isHigh && !s3.isHigh))
            continue;
         if(!(s0.label == SWING_HH && s1.label == SWING_LL))
            continue;
         const double leg = MathAbs(s2.price - s3.price);
         if(leg <= _Point)
            continue;
         const double llExt = s3.price - s1.price;
         const double hhBrk = s0.price - s2.price;
         if(llExt < (leg * 0.10) || hhBrk < (leg * 0.30))
            continue;
         const double retestPts = MathAbs(c1 - s3.price) / _Point;
         if(retestPts > 200.0)
            continue;
         quality = MathMax(0.0,MathMin(100.0,72.0 + MathMin(20.0,(hhBrk / MathMax(leg,_Point)) * 20.0)));
         return true;
        }
      else
        {
         if(!(!s0.isHigh && s1.isHigh && !s2.isHigh && s3.isHigh))
            continue;
         if(!(s0.label == SWING_LL && s1.label == SWING_HH))
            continue;
         const double leg = MathAbs(s3.price - s2.price);
         if(leg <= _Point)
            continue;
         const double hhExt = s1.price - s3.price;
         const double llBrk = s2.price - s0.price;
         if(hhExt < (leg * 0.10) || llBrk < (leg * 0.30))
            continue;
         const double retestPts = MathAbs(c1 - s3.price) / _Point;
         if(retestPts > 200.0)
            continue;
         quality = MathMax(0.0,MathMin(100.0,72.0 + MathMin(20.0,(llBrk / MathMax(leg,_Point)) * 20.0)));
         return true;
        }
     }

   return false;
  }

bool DetectSupervisorP4SGB(const FVGZone &zone,const bool bullish,double &quality)
  {
   quality = 0.0;
   const double atrPts = MathMax(1.0,ComputeATRPoints(MathMax(2,InpSupervisorP4ATRPeriod)));
   const int minBase = MathMax(1,InpSupervisorP4SgbMinBaseCandles);
   const int maxBase = MathMax(minBase,InpSupervisorP4SgbMaxBaseCandles);
   int baseCount = 0;
   for(int i = 1; i <= maxBase; i++)
     {
      const double h = iHigh(_Symbol,InpExecutionTF,i);
      const double l = iLow(_Symbol,InpExecutionTF,i);
      if(h < zone.lower || l > zone.upper)
         continue;
      const double o = iOpen(_Symbol,InpExecutionTF,i);
      const double c = iClose(_Symbol,InpExecutionTF,i);
      const double bodyPct = 100.0 * MathAbs(c - o) / MathMax(h - l,_Point);
      if(bodyPct <= 45.0)
         baseCount++;
     }
   if(baseCount < minBase)
      return false;

   const double mid = (zone.lower + zone.upper) * 0.5;
   double ref = zone.structureLevel;
   if(ref <= 0.0)
      ref = iClose(_Symbol,InpExecutionTF,1);
   const double distAtr = (MathAbs(mid - ref) / _Point) / atrPts;
   if(distAtr < MathMax(0.1,InpSupervisorP4SgbMinDistAtr) || distAtr > MathMax(InpSupervisorP4SgbMinDistAtr + 0.1,InpSupervisorP4SgbMaxDistAtr))
      return false;

   const double o1 = iOpen(_Symbol,InpExecutionTF,1);
   const double c1 = iClose(_Symbol,InpExecutionTF,1);
   const double zoneSize = MathMax(zone.upper - zone.lower,_Point);
   double through = 0.0;
   if(bullish)
      through = MathMax(0.0,zone.lower - MathMin(o1,c1));
   else
      through = MathMax(0.0,MathMax(o1,c1) - zone.upper);
   if((through / zoneSize) >= 0.60)
      return false;

   quality = MathMax(0.0,MathMin(100.0,62.0 + MathMin(26.0,(double)baseCount * 4.0)));
   return true;
  }

bool DetectSupervisorP4CPLQ(const FVGZone &zone,const bool bullish,const bool hasCompression,double &quality)
  {
   quality = 0.0;
   if(!hasCompression)
      return false;

   const double h1 = iHigh(_Symbol,InpExecutionTF,1);
   const double l1 = iLow(_Symbol,InpExecutionTF,1);
   const double c1 = iClose(_Symbol,InpExecutionTF,1);
   const double c2 = iClose(_Symbol,InpExecutionTF,2);
   const double rPts = MathMax((h1 - l1) / _Point,1.0);

   double sweepPts = 0.0;
   bool insideBack = false;
   if(bullish)
     {
      sweepPts = MathMax(0.0,(zone.lower - l1) / _Point);
      insideBack = (c1 > zone.lower || c2 > zone.lower);
     }
   else
     {
      sweepPts = MathMax(0.0,(h1 - zone.upper) / _Point);
      insideBack = (c1 < zone.upper || c2 < zone.upper);
     }

   const double wickPct = sweepPts / rPts;
   if(sweepPts < MathMax(20,InpSupervisorP4CplqSweepMinPts))
      return false;
   if(wickPct < 0.35)
      return false;
   if(!insideBack)
      return false;

   quality = MathMax(0.0,MathMin(100.0,68.0 + MathMin(24.0,wickPct * 40.0)));
   return true;
  }

double ComputeMemoryLayerScore(FVGZone &zone,const bool bullish)
  {
   zone.memDisplacement = false;
   zone.memUnfilled = false;
   zone.memStructure = false;
   zone.memLiquidity = false;
   zone.memScore = 0.0;

   if(!InpUseSupervisorMemoryLayer)
      return 0.0;

   const int bars = Bars(_Symbol,InpExecutionTF);
   const int lookback = MathMax(20,MathMin(600,InpMemoryLookbackBars));
   if(bars < MathMax(lookback,40))
      return 0.0;

   const double atrPts = MathMax(1.0,ComputeATRPoints(MathMax(2,InpSupervisorP4ATRPeriod)));
   const double o1 = iOpen(_Symbol,InpExecutionTF,1);
   const double c1 = iClose(_Symbol,InpExecutionTF,1);
   const double h1 = iHigh(_Symbol,InpExecutionTF,1);
   const double l1 = iLow(_Symbol,InpExecutionTF,1);
   const double h2 = iHigh(_Symbol,InpExecutionTF,2);
   const double l2 = iLow(_Symbol,InpExecutionTF,2);
   const double h3 = iHigh(_Symbol,InpExecutionTF,3);
   const double l3 = iLow(_Symbol,InpExecutionTF,3);
   const double c2 = iClose(_Symbol,InpExecutionTF,2);

   const double range1 = MathMax(h1 - l1,_Point);
   const double range1Pts = range1 / _Point;
   const double bodyPct = MathAbs(c1 - o1) / range1;

   double dispScore = 0.0;
   double unfilledScore = 0.0;
   double structScore = 0.0;
   double liqScore = 0.0;

   // Displacement (adapted from MarketMemoryZones with proper ATR/volume handling).
   {
      const double minDispPts = MathMax(1.0,InpMemoryMinCandleSizeATR) * atrPts;
      const double overlapPrev2 = MathMax(0.0,MathMin(h1,h2) - MathMax(l1,l2)) / MathMax(range1,_Point);
      const double overlapPrev3 = MathMax(0.0,MathMin(h1,h3) - MathMax(l1,l3)) / MathMax(range1,_Point);
      const bool directional = bullish ? (c1 > o1) : (c1 < o1);
      bool volOk = true;
      if(InpMemoryFilterByVolume)
        {
         const int volPeriod = MathMin(20,lookback);
         double volSum = 0.0;
         int volCount = 0;
         for(int i = 2; i < 2 + volPeriod; i++)
           {
            const long tv = iVolume(_Symbol,InpExecutionTF,i);
            if(tv <= 0)
               continue;
            volSum += (double)tv;
            volCount++;
           }
         const double avgVol = (volCount > 0) ? (volSum / volCount) : 0.0;
         const double nowVol = (double)iVolume(_Symbol,InpExecutionTF,1);
         const double ratio = (avgVol > 0.0) ? (nowVol / avgVol) : 1.0;
         volOk = (ratio >= MathMax(1.0,InpMemoryMinVolumeRatio));
      }
      if(range1Pts >= minDispPts && directional && bodyPct >= 0.60 && overlapPrev2 <= 0.30 && overlapPrev3 <= 0.30 && volOk)
        {
         zone.memDisplacement = true;
         const double distMul = range1Pts / MathMax(minDispPts,1.0);
         dispScore = MathMax(0.0,MathMin(100.0,62.0 + MathMin(26.0,(distMul - 1.0) * 22.0) + MathMin(10.0,(bodyPct - 0.60) * 60.0)));
        }
   }

   // Unfilled inefficiency (FVG-style inefficiency check).
   {
      bool hasGap = false;
      double gapPts = 0.0;
      if(bullish)
        {
         if(l1 > h3 && l2 > h3)
           {
            hasGap = true;
            gapPts = (MathMin(l1,l2) - h3) / _Point;
           }
        }
      else
        {
         if(h1 < l3 && h2 < l3)
           {
            hasGap = true;
            gapPts = (l3 - MathMax(h1,h2)) / _Point;
           }
        }
      if(hasGap && gapPts >= (0.15 * atrPts))
        {
         zone.memUnfilled = true;
         unfilledScore = MathMax(0.0,MathMin(100.0,55.0 + MathMin(30.0,(gapPts / MathMax(atrPts,1.0)) * 30.0)));
        }
   }

   // Structure transition using BOS/CHOCH information.
   {
      bool bos = false;
      bool choch = false;
      DetectRecentBOSCHOCH(bullish,bos,choch);
      if(choch || bos)
        {
         zone.memStructure = true;
         structScore = choch ? 90.0 : 72.0;
        }
   }

   // Liquidity sweep origin.
   {
      if(bullish)
        {
         const bool sweep = (l1 < l2 && c1 > l2 && c1 > c2 && c1 > o1 && bodyPct >= 0.50);
         if(sweep)
           {
            zone.memLiquidity = true;
            const double sweepPts = MathMax(0.0,(l2 - l1) / _Point);
            liqScore = MathMax(0.0,MathMin(100.0,66.0 + MathMin(22.0,(sweepPts / MathMax(0.5 * atrPts,1.0)) * 14.0)));
           }
        }
      else
        {
         const bool sweep = (h1 > h2 && c1 < h2 && c1 < c2 && c1 < o1 && bodyPct >= 0.50);
         if(sweep)
           {
            zone.memLiquidity = true;
            const double sweepPts = MathMax(0.0,(h1 - h2) / _Point);
            liqScore = MathMax(0.0,MathMin(100.0,66.0 + MathMin(22.0,(sweepPts / MathMax(0.5 * atrPts,1.0)) * 14.0)));
           }
        }
   }

   double sum = 0.0;
   int cnt = 0;
   if(zone.memDisplacement)
     {
      sum += dispScore;
      cnt++;
     }
   if(zone.memUnfilled)
     {
      sum += unfilledScore;
      cnt++;
     }
   if(zone.memStructure)
     {
      sum += structScore;
      cnt++;
     }
   if(zone.memLiquidity)
     {
      sum += liqScore;
      cnt++;
     }

   double score = (cnt > 0) ? (sum / cnt) : 0.0;
   if(zone.memDisplacement && zone.memLiquidity)
      score += 4.0;
   if(zone.memStructure && zone.memUnfilled)
      score += 3.0;

   zone.memScore = MathMax(0.0,MathMin(100.0,score));

   if(InpMemoryLogs)
      PrintFormat("ForceX MemoryLayer (%s): score=%.1f disp=%s unf=%s struct=%s liq=%s",
                  zone.name,
                  zone.memScore,
                  zone.memDisplacement ? "true" : "false",
                  zone.memUnfilled ? "true" : "false",
                  zone.memStructure ? "true" : "false",
                  zone.memLiquidity ? "true" : "false");

   return zone.memScore;
  }

double ComputeSupervisorPhase4Score(FVGZone &zone,const bool bullish)
  {
   zone.p4Sgb = false;
   zone.p4Flippy = false;
   zone.p4Compression = false;
   zone.p4Cplq = false;
   zone.p4ThreeDrive = false;
   zone.p4Qm = false;
   zone.p4KingType = 0;
   zone.p4PatternQuality = 0.0;
   zone.p4Score = 0.0;

   double qSgb = 0.0, qFlippy = 0.0, qComp = 0.0, qCplq = 0.0, q3d = 0.0, qQm = 0.0, qKing = 0.0;
   int kingType = 0;
   zone.p4Sgb = DetectSupervisorP4SGB(zone,bullish,qSgb);
   zone.p4Flippy = DetectSupervisorP4Flippy(zone,bullish,qFlippy);
   zone.p4Compression = DetectSupervisorP4Compression(bullish,qComp);
   zone.p4Cplq = DetectSupervisorP4CPLQ(zone,bullish,zone.p4Compression,qCplq);
   zone.p4ThreeDrive = DetectSupervisorP4ThreeDrive(bullish,q3d);
   zone.p4Qm = DetectSupervisorP4QM(bullish,qQm);
   if(DetectSupervisorP4KingCandle(bullish,kingType,qKing))
      zone.p4KingType = kingType;

   double qSum = 0.0;
   int qCnt = 0;
   if(zone.p4Sgb)
     {
      qSum += qSgb;
      qCnt++;
     }
   if(zone.p4Flippy)
     {
      qSum += qFlippy;
      qCnt++;
     }
   if(zone.p4Compression)
     {
      qSum += qComp;
      qCnt++;
     }
   if(zone.p4Cplq)
     {
      qSum += qCplq;
      qCnt++;
     }
   if(zone.p4ThreeDrive)
     {
      qSum += q3d;
      qCnt++;
     }
   if(zone.p4Qm)
     {
      qSum += qQm;
      qCnt++;
     }
   zone.p4PatternQuality = (qCnt > 0) ? (qSum / qCnt) : 0.0;

   const double htfBias = BiasAllowsDirection(bullish) ? 100.0 : 0.0;
   double liq = zone.liquidityLikelihood;
   if(HasLiquiditySweep(bullish) || zone.sweepWick > 0.0)
      liq = MathMax(liq,85.0);
   const double structure = (zone.bosAligned || zone.chochAligned) ? 100.0 : 0.0;
   const double king = (zone.p4KingType > 0) ? qKing : 0.0;

   const double w1 = MathMax(0.0,InpSupervisorP4W_HtfBias);
   const double w2 = MathMax(0.0,InpSupervisorP4W_PatternQuality);
   const double w3 = MathMax(0.0,InpSupervisorP4W_LiquiditySweep);
   const double w4 = MathMax(0.0,InpSupervisorP4W_KingCandle);
   const double w5 = MathMax(0.0,InpSupervisorP4W_StructureBreak);
   const double wSum = w1 + w2 + w3 + w4 + w5;
   if(wSum <= 0.0)
      return 0.0;

   double score = (htfBias * w1 + zone.p4PatternQuality * w2 + liq * w3 + king * w4 + structure * w5) / wSum;

    if(InpUseSupervisorMemoryLayer)
      {
       const double memScore = ComputeMemoryLayerScore(zone,bullish);
       const double blend = MathMax(0.0,MathMin(60.0,InpMemoryBlendPct)) / 100.0;
       score = score * (1.0 - blend) + memScore * blend;
      }

   if(zone.chochAligned)
      score += 5.0;
   if(zone.p4Qm && zone.p4Cplq)
      score += 5.0;

   zone.p4Score = MathMax(0.0,MathMin(100.0,score));
   return zone.p4Score;
  }

bool ApplySupervisorPhase4Gate(FVGZone &zone,const bool bullish,const bool forEntry,string &reason,string &tagOut)
  {
   reason = "";
   tagOut = "";
   if(!InpUseSupervisorPhase4)
      return true;

   const double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   const double spreadPts = MathMax(0.0,(ask - bid) / _Point);
   const bool spreadBlocked = (spreadPts > GetSupervisorP4SpreadMaxPoints());
   if(spreadBlocked && forEntry)
     {
      reason = "phase4 spread filter";
      return false;
     }

   const double atrPts = MathMax(1.0,ComputeATRPoints(MathMax(2,InpSupervisorP4ATRPeriod)));
   const double r1Pts = MathMax(1.0,(iHigh(_Symbol,InpExecutionTF,1) - iLow(_Symbol,InpExecutionTF,1)) / _Point);
   const double volMult = r1Pts / atrPts;
   const bool volBlocked = (volMult > GetSupervisorP4VolSpikeThreshold() && !zone.doubleSweep);
   if(volBlocked && forEntry)
     {
      reason = "phase4 volatility spike filter";
      return false;
     }

   const double score = ComputeSupervisorPhase4Score(zone,bullish);
   const int armTh = MathMax(0,MathMin(100,InpSupervisorP4ArmThreshold));
   const int enterTh = MathMax(0,MathMin(100,InpSupervisorP4EnterThreshold));
   const int cancelTh = MathMax(0,MathMin(100,InpSupervisorP4CancelThreshold));
   const int htfOverride = MathMax(0,MathMin(100,InpSupervisorP4HTFOverrideScore));
   const int req = forEntry ? enterTh : armTh;

   if(InpUseSupervisorMemoryLayer && forEntry)
     {
      const int memMin = MathMax(0,MathMin(100,InpMemoryMinScore));
      if(zone.memScore < memMin)
        {
         reason = "memory layer score low";
         return false;
        }
      if(InpMemoryRequireLiquiditySweep && !zone.memLiquidity)
        {
         reason = "memory layer requires liquidity sweep";
         return false;
        }
     }

   if(!forEntry && score < cancelTh)
     {
      zone.flowState = FLOW_IDLE;
      zone.gateTicks = 0;
      reason = "phase4 cancel threshold hit";
      return false;
     }

   if(score < req)
     {
      const bool allowOverride = forEntry && score >= htfOverride && BiasAllowsDirection(bullish) && (zone.bosAligned || zone.chochAligned);
      const bool allowAlignOverride = forEntry && zone.alignmentScore >= (req + 8.0) && (zone.bosAligned || zone.chochAligned);
      if(!allowOverride && !allowAlignOverride)
        {
         reason = forEntry ? "phase4 enter threshold not met" : "phase4 arm threshold not met";
         return false;
        }
     }

   if(forEntry && InpSupervisorP4RequireCorePattern)
     {
      const bool corePattern = zone.p4Sgb || zone.p4Qm || zone.p4Cplq || (zone.p4KingType > 0 && zone.p4Flippy);
      if(!corePattern)
        {
         reason = "phase4 requires core pattern";
         return false;
        }
     }

   tagOut = "P4" + IntegerToString((int)MathRound(zone.p4Score));
   if(zone.p4Qm)
      tagOut += "_QM";
   if(zone.p4Cplq)
      tagOut += "_CPLQ";
   if(zone.p4Sgb)
      tagOut += "_SGB";
   if(zone.p4KingType > 0)
      tagOut += "_K" + IntegerToString(zone.p4KingType);
   if(InpUseSupervisorMemoryLayer)
      tagOut += "_M" + IntegerToString((int)MathRound(zone.memScore));

   if(InpSupervisorP4Logs)
      PrintFormat("ForceX Phase4 gate pass (%s): score=%.1f pq=%.1f king=%d sgb=%s flippy=%s comp=%s cplq=%s 3d=%s qm=%s",
                  zone.name,
                  zone.p4Score,
                  zone.p4PatternQuality,
                  zone.p4KingType,
                  zone.p4Sgb ? "true" : "false",
                  zone.p4Flippy ? "true" : "false",
                  zone.p4Compression ? "true" : "false",
                  zone.p4Cplq ? "true" : "false",
                  zone.p4ThreeDrive ? "true" : "false",
                  zone.p4Qm ? "true" : "false");

   return true;
  }

int GetSupervisorPhase3ThresholdBoost(const bool forEntry)
  {
   if(!InpUseSupervisorPhase3)
      return 0;

   const int regime = GetCurrentMarketRegime();
   if(regime == REGIME_RANGE)
      return MathMax(0,forEntry ? InpSupervisorRangeEnterBoost : InpSupervisorRangeArmBoost);
   if(regime == REGIME_HIGHVOL)
      return MathMax(0,forEntry ? InpSupervisorHighVolEnterBoost : InpSupervisorHighVolArmBoost);
   return 0;
  }

int GetSupervisorPhase3RequiredHits(const int baseHits)
  {
   int required = MathMax(1,baseHits);
   if(!InpUseSupervisorPhase3)
      return required;

   const int regime = GetCurrentMarketRegime();
   if(regime == REGIME_RANGE)
      required += MathMax(0,InpSupervisorRangeHitsAdd);
   else if(regime == REGIME_HIGHVOL)
      required += MathMax(0,InpSupervisorHighVolHitsAdd);
   return MathMax(1,required);
  }

double ComputeSupervisorAlignmentScore(FVGZone &zone,const bool bullish,const int triggerHits,const bool priceTrigger)
  {
   bool bos = false;
   bool choch = false;
   DetectRecentBOSCHOCH(bullish,bos,choch);
   zone.bosAligned = bos;
   zone.chochAligned = choch;

   ComputeFVGQualityTier(zone);
   zone.liquidityLikelihood = ComputeLiquidityTakeLikelihood(zone,bullish);

   double score = 0.0;
   if(InpUseSupervisorPhase3)
     {
      const double bosW = MathMax(0.0,MathMin(50.0,InpSupervisorBosWeight));
      const double chochW = MathMax(0.0,MathMin(60.0,InpSupervisorChochWeight));
      if(choch)
         score += chochW;
      else if(bos)
         score += bosW;
      else
         score -= 8.0;
     }
   else if(bos || choch)
      score += 30.0;

   score += zone.qualityScore * 0.25;
   score += zone.liquidityLikelihood * 0.20;

   if(priceTrigger || triggerHits > 0)
      score += 10.0;

   if(BiasAllowsDirection(bullish))
      score += 10.0;

   const double atrPts = ComputeATRPoints(MathMax(2,InpSupervisorATRPeriod));
   if(atrPts > 0.0)
     {
      const double rangePts = (iHigh(_Symbol,InpExecutionTF,1) - iLow(_Symbol,InpExecutionTF,1)) / _Point;
      const double ratio = rangePts / atrPts;
      if(ratio >= 0.8 && ratio <= 2.5)
         score += 5.0;
     }

   zone.alignmentScore = MathMax(0.0,MathMin(100.0,score));
   return zone.alignmentScore;
  }

bool ApplySupervisorPhase2Gate(FVGZone &zone,const bool bullish,const int triggerHits,const bool priceTrigger,const bool forEntry,string &reason)
  {
   reason = "";
   if(!InpUseSupervisorPhase2)
      return true;

   const double align = ComputeSupervisorAlignmentScore(zone,bullish,triggerHits,priceTrigger);
   const int armTh = MathMax(0,MathMin(100,InpSupervisorArmThreshold));
   const int enterTh = MathMax(0,MathMin(100,InpSupervisorEnterThreshold));
   int cancelTh = MathMax(0,MathMin(100,InpSupervisorCancelThreshold));
   int req = forEntry ? enterTh : armTh;
   req = MathMin(100,req + GetSupervisorPhase3ThresholdBoost(forEntry));
   cancelTh = MathMin(100,cancelTh + (GetSupervisorPhase3ThresholdBoost(false) / 2));

   if(zone.gapAtr < MathMax(0.01,InpSupervisorMinGapATR))
     {
      reason = "phase2 gapATR below minimum";
      return false;
     }

   if(InpSupervisorBlockFakeFVG && zone.fakeConfirmed)
     {
      reason = "phase2 fake FVG confirmed";
      return false;
     }

   if(InpSupervisorRequireLiqLikelihood)
     {
      const int liqTh = MathMax(0,MathMin(100,InpSupervisorLiqThreshold));
      if(zone.liquidityLikelihood < liqTh)
        {
         reason = "phase2 liquidity likelihood low";
         return false;
        }
     }

   if(!forEntry && align < cancelTh)
     {
      zone.flowState = FLOW_IDLE;
      zone.gateTicks = 0;
      reason = "phase2 cancel threshold hit";
      return false;
     }

   if(InpUseSupervisorPhase3 && forEntry && InpSupervisorRequireBosOrChochEntry)
     {
      if(!zone.bosAligned && !zone.chochAligned)
        {
         reason = "phase3 requires BOS/CHOCH for entry";
         return false;
        }
     }

   if(align < req)
     {
      reason = forEntry ? "phase2 enter threshold not met" : "phase2 arm threshold not met";
      return false;
     }

   if(InpSupervisorDebugLogs || InpSupervisorPhase3Logs)
     {
      PrintFormat("ForceX Phase2 gate pass (%s): align=%.1f liq=%.1f q=%.1f tier=%d bos=%s choch=%s fake=%s",
                  zone.name,
                  align,
                  zone.liquidityLikelihood,
                  zone.qualityScore,
                  zone.qualityTier,
                  zone.bosAligned ? "true" : "false",
                  zone.chochAligned ? "true" : "false",
                  zone.fakeConfirmed ? "true" : "false");
     }
   return true;
  }

double ComputeAIScore(const FVGZone &zone)
  {
   double score = 0.0;

   if(BiasAllowsDirection(zone.bullish))
      score += InpW_Bias;

   if(HasLiquiditySweep(zone.bullish))
      score += InpW_Sweep;

   if(zone.bodyPct >= InpMinBodyDisplacementPct)
      score += InpW_Displacement;

   if(HasMTFOverlap(zone))
      score += InpW_FVGConfluence;

   if(ValidateOrderBlockConfluence(zone.bullish,zone))
      score += InpW_OBAlignment;

   return score;
  }

bool CreateRec(const string objName,const datetime time1,const double price1,const datetime time2,const double price2,const color clr)
  {
   if(ObjectFind(0,objName) < 0)
     {
      if(!ObjectCreate(0,objName,OBJ_RECTANGLE,0,time1,price1,time2,price2))
         return false;
     }

   ObjectSetInteger(0,objName,OBJPROP_TIME,0,time1);
   ObjectSetDouble(0,objName,OBJPROP_PRICE,0,price1);
   ObjectSetInteger(0,objName,OBJPROP_TIME,1,time2);
   ObjectSetDouble(0,objName,OBJPROP_PRICE,1,price2);
   ObjectSetInteger(0,objName,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,objName,OBJPROP_FILL,true);
   ObjectSetInteger(0,objName,OBJPROP_BACK,false);
   ObjectSetInteger(0,objName,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,objName,OBJPROP_WIDTH,1);

   return true;
  }

int CountFVGObjects()
  {
   int count = 0;
   const int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0,i);
      if(StringFind(name,FVG_PREFIX) == 0)
         count++;
     }
   return count;
  }

bool RegisterFVGZone(const bool bullish,const int i,const double low0,const double high0,const double low2,const double high2,const double bodyPct)
  {
   const int minGapPoints = GetEffectiveMinGapPoints();

   const datetime time1 = iTime(_Symbol,InpExecutionTF,i+1);
   if(time1 <= 0)
      return false;

   const int sec = PeriodSeconds(InpExecutionTF);
   if(sec <= 0)
      return false;

   const datetime time2 = time1 + (datetime)(sec * InpFVGRectBars);
   const string name = FVG_PREFIX + (bullish ? "UP_" : "DN_") + IntegerToString((int)time1);

   const int existing = FindZoneByName(name);
   if(existing >= 0)
      return false;

   FVGZone z;
   z.name = name;
   z.bullish = bullish;
   z.time1 = time1;
   z.time2 = time2;
   z.anchorShift = i+1;
   z.active = true;
   z.traded = false;
   z.bodyPct = bodyPct;
   z.flowState = FLOW_IDLE;
   z.gateTicks = 0;
   z.gateBarTime = 0;
   z.structureLevel = 0.0;
   z.confidence = 0.0;
   z.fvgRespected = false;
   z.fvgDisrespected = false;
   z.sweepWick = 0.0;
   z.targetLiquidity = 0.0;
   z.doubleSweep = false;
   z.gapAtr = 0.0;
   z.qualityScore = 0.0;
   z.qualityTier = 0;
   z.fakeConfirmed = false;
   z.liquidityLikelihood = 0.0;
   z.alignmentScore = 0.0;
   z.bosAligned = false;
   z.chochAligned = false;
   z.ageBars = 0;
   z.p4Sgb = false;
   z.p4Flippy = false;
   z.p4Compression = false;
   z.p4Cplq = false;
   z.p4ThreeDrive = false;
   z.p4Qm = false;
   z.p4KingType = 0;
   z.p4PatternQuality = 0.0;
   z.p4Score = 0.0;
   z.memDisplacement = false;
   z.memUnfilled = false;
   z.memStructure = false;
   z.memLiquidity = false;
   z.memScore = 0.0;

   if(bullish)
     {
      z.lower = high2;
      z.upper = low0;
      z.gapPoints = (low0 - high2) / _Point;
     }
   else
     {
      z.lower = high0;
      z.upper = low2;
      z.gapPoints = (low2 - high0) / _Point;
     }

   if(z.upper <= z.lower)
      return false;

   if(z.gapPoints < minGapPoints)
      return false;

   if(InpUseSupervisorPhase2)
     {
      ComputeFVGQualityTier(z);
     }

   const color zoneColor = bullish ? InpBullFVGColor : InpBearFVGColor;
   if(!CreateRec(z.name,z.time1,z.lower,z.time2,z.upper,zoneColor))
      return false;

   const int n = ArraySize(g_zones);
   ArrayResize(g_zones,n+1);
   g_zones[n] = z;

   return true;
  }

void ScanAndBuildFVGs()
  {
   const int minGapPoints = GetEffectiveMinGapPoints();

   const int bars = Bars(_Symbol,InpExecutionTF);
   if(bars < 10)
      return;

   int scanBars = InpLookbackBars;
   if(InpUseVisibleBars)
      scanBars = (int)ChartGetInteger(0,CHART_VISIBLE_BARS) + 5;

   scanBars = MathMin(scanBars,bars - 3);
   if(scanBars < 1)
      return;

   for(int i = scanBars; i >= 1; i--)
     {
      const double open1 = iOpen(_Symbol,InpExecutionTF,i+1);
      const double close1 = iClose(_Symbol,InpExecutionTF,i+1);
      const double high1 = iHigh(_Symbol,InpExecutionTF,i+1);
      const double low1 = iLow(_Symbol,InpExecutionTF,i+1);

      const double range1 = high1 - low1;
      if(range1 <= 0.0)
         continue;

      const double bodyPct = (MathAbs(close1 - open1) / range1) * 100.0;
      if(bodyPct < InpMinBodyDisplacementPct)
         continue;

      const double low0  = iLow(_Symbol,InpExecutionTF,i);
      const double high0 = iHigh(_Symbol,InpExecutionTF,i);
      const double low2  = iLow(_Symbol,InpExecutionTF,i+2);
      const double high2 = iHigh(_Symbol,InpExecutionTF,i+2);

      const bool fvgUp = (low0 > high2) && (((low0 - high2) / _Point) >= minGapPoints);
      const bool fvgDown = (low2 > high0) && (((low2 - high0) / _Point) >= minGapPoints);

      if(fvgUp)
         RegisterFVGZone(true,i,low0,high0,low2,high2,bodyPct);

      if(fvgDown)
         RegisterFVGZone(false,i,low0,high0,low2,high2,bodyPct);
     }
  }

bool CanOpenTrade(const bool bullish)
  {
   if(InpTradeOnlyV75Symbols && !g_isV75 && !IsCrash900ProfileActive())
      return false;

   if(bullish && !InpAllowBuy)
      return false;

   if(!bullish && !InpAllowSell)
      return false;

   if(g_dayLocked)
      return false;

   const int regime = GetCurrentMarketRegime();
   if(regime == REGIME_UNKNOWN)
      return false;
   if(regime >= 0 && regime < ArraySize(g_regimeDisabled) && g_regimeDisabled[regime])
      return false;

   string riskReason = "";
   if(!g_riskEngine.CanTrade(CurrentExecBarIndex(),riskReason))
     {
      if(InpDebugMode && StringLen(riskReason) > 0)
         PrintFormat("[RISK] blocked open (%s): %s",bullish ? "BUY" : "SELL",riskReason);
      return false;
     }

   const int maxTradesToday = GetEffectiveMaxTradesPerDay();
   if(maxTradesToday > 0 && g_tradesToday >= maxTradesToday)
      return false;

   if(!InSessionWindow())
      return false;

   if(InpOnePositionAtATime && HasOpenPositionByMagic())
      return false;

   return true;
  }

bool ExecuteMarketOrder(FVGZone &zone)
  {
   const bool kutMilzCleanMode = (InpUseCrystalHeikinSignal && InpUseKUTMilzCleanSetupOnly);
   if(!kutMilzCleanMode)
     {
      if(InpDebugMode)
         PrintFormat("ForceX legacy entry path disabled (%s). Enable KUTMilz clean mode for trading.",zone.name);
      return false;
     }

   const bool bypassBlocks = InpKUTMilzBypassEntryBlocks;

   if(bypassBlocks)
     {
      if(InpTradeOnlyV75Symbols && !g_isV75 && !IsCrash900ProfileActive())
         return false;
      if(zone.bullish && !InpAllowBuy)
         return false;
      if(!zone.bullish && !InpAllowSell)
         return false;
     }
   else if(!CanOpenTrade(zone.bullish))
      return false;

   string crystalReason = "";
   string crystalTag = "";
   datetime crystalSignalBar = 0;
   if(!ConfirmCrystalSignal(zone.bullish,crystalReason,crystalTag,crystalSignalBar))
     {
      if(InpTriggerDecisionLogs || InpDebugMode)
         PrintFormat("ForceX crystal gate blocked (%s): %s",zone.name,crystalReason);
      return false;
     }
   if(InpDebugMode && StringLen(crystalTag) > 0)
      PrintFormat("[SIGNAL] %s %s",zone.name,crystalTag);

   // Hard lock: only KUTMilz immediate execution path is allowed.
   return ExecuteImmediateSignalOrder(zone,crystalSignalBar,crystalTag);

   if(g_signalEngine.State() != FLOW_ENTRY_READY && !InpSimpleModeNoGates)
     {
      if(InpDebugMode)
         PrintFormat("[FLOW] order blocked: state=%s expected=ENTRY_READY",
                     FxFlowStateToText(g_signalEngine.State()));
      return false;
     }

   if(InpSimpleModeNoGates)
     {
      string reason = "";
      const int regime = GetCurrentMarketRegime();
      const string setupTag = BuildSetupTag(zone,"simple",regime);

      double requestedLots = InpFixedLots;
      requestedLots *= GetRegimeLotMultiplier();
      const double fallbackVolume = NormalizeVolume(requestedLots);
      if(fallbackVolume <= 0.0)
         return false;

      g_trade.SetTypeFillingBySymbol(_Symbol);
      g_trade.SetDeviationInPoints(MathMax(0,GetEffectiveSlippagePoints()));

      MqlTick tick;
      if(!GetFreshTick(tick,reason))
        {
         PrintFormat("ForceX simple order blocked (%s): %s",zone.name,reason);
         return false;
        }

      const int attempts = MathMax(1,GetEffectiveOrderRetries());
      for(int a = 0; a < attempts; a++)
        {
         reason = "";
         if(!GetFreshTick(tick,reason))
           {
            if(a < attempts - 1 && InpRetryDelayMs > 0)
               Sleep(InpRetryDelayMs);
            continue;
           }

         double sl = 0.0;
         double tp = 0.0;
         if(!BuildOrderLevels(zone.bullish,zone,tick,sl,tp,reason))
           {
            PrintFormat("ForceX simple order blocked (%s): %s",zone.name,reason);
            return false;
           }

         const double volume = ComputeRiskSizedVolume(zone.bullish,tick,sl,fallbackVolume);
         if(volume <= 0.0)
           {
            PrintFormat("ForceX simple order blocked (%s): volume sizing failed",zone.name);
            return false;
           }

         if(!ValidateMarketModel(zone.bullish,volume,tick,reason))
           {
            PrintFormat("ForceX simple order blocked (%s): %s",zone.name,reason);
            return false;
           }

         const bool sent = zone.bullish ?
                           g_trade.Buy(volume,_Symbol,0.0,sl,tp,zone.name) :
                           g_trade.Sell(volume,_Symbol,0.0,sl,tp,zone.name);

         if(sent)
           {
            if(InpCrystalOneSignalPerBar && crystalSignalBar > 0)
              {
               if(zone.bullish)
                  g_lastCrystalBuyBar = crystalSignalBar;
               else
                  g_lastCrystalSellBar = crystalSignalBar;
              }
            g_signalEngine.TryTransition(FLOW_EXECUTED,CurrentExecBarIndex(),"simple order sent");
            g_signalEngine.TryTransition(FLOW_MANAGING,CurrentExecBarIndex(),"simple managing");
            zone.flowState = FLOW_MANAGEMENT_STATE;
            g_tradesToday++;
            if(InpUseSetupTagEngine)
              {
               if(AttachResultDealToTag(setupTag))
                  QueueTagEvent("Entry accepted (SIMPLE): " + setupTag);
               else
                  QueueTagEvent("Entry accepted (SIMPLE) but tag link missing: " + setupTag);
              }
            return true;
           }

         int rc = (int)g_trade.ResultRetcode();
         if(InpUseInvalidStopsRescue && IsInvalidStopsRetcode(rc))
           {
            const bool rescueSent = zone.bullish ?
                                    g_trade.Buy(volume,_Symbol,0.0,0.0,0.0,zone.name + "_RS") :
                                    g_trade.Sell(volume,_Symbol,0.0,0.0,0.0,zone.name + "_RS");
            if(rescueSent)
              {
               if(InpCrystalOneSignalPerBar && crystalSignalBar > 0)
                 {
                  if(zone.bullish)
                     g_lastCrystalBuyBar = crystalSignalBar;
                  else
                     g_lastCrystalSellBar = crystalSignalBar;
                 }
               zone.flowState = FLOW_MANAGEMENT_STATE;
               g_tradesToday++;
               if(InpUseSetupTagEngine)
                 {
                  if(AttachResultDealToTag(setupTag))
                     QueueTagEvent("Rescue entry accepted (SIMPLE): " + setupTag);
                  else
                     QueueTagEvent("Rescue entry accepted (SIMPLE) but tag link missing: " + setupTag);
                 }
               string attachReason = "";
               if(!AttachProtectiveStopsAfterEntry(zone.bullish,zone,attachReason))
                  PrintFormat("ForceX simple rescue opened without SL/TP attach (%s): %s",zone.name,attachReason);
               return true;
              }

            rc = (int)g_trade.ResultRetcode();
           }

         if(a < attempts - 1 && (IsRetryRetcode(rc) || IsInvalidStopsRetcode(rc)))
           {
            if(InpRetryDelayMs > 0)
               Sleep(InpRetryDelayMs);
            continue;
           }

         PrintFormat("ForceX simple order failed (%s): retcode=%d, comment=%s",zone.name,rc,g_trade.ResultRetcodeDescription());
         return false;
        }

      PrintFormat("ForceX simple order failed (%s): market retries exhausted",zone.name);
      return false;
     }

   if(InpUseInstitutionalStateModel && InpInstitutionalRequireReady)
     {
      if(zone.flowState != FLOW_EXECUTION_STATE)
         return false;
      if(zone.confidence < GetAdaptiveExecutionMinConfidence())
         return false;
     }

   string reason = "";
   double patternScore = InpEnablePatternModel ? ComputePatternScore(zone,reason) : 100.0;
   string patternPhase = reason;
   reason = "";

   string strongReason = "";
   const bool strongPass = PassStrongEntryFilters(zone,strongReason);

   FVGZone p2Zone = zone;
   string p2Reason = "";
   const bool phase2Pass = ApplySupervisorPhase2Gate(p2Zone,zone.bullish,GetEffectiveMinTriggerHits(),true,true,p2Reason);

   FVGZone p4Zone = zone;
   string phase4Reason = "";
   string phase4Tag = "";
   const bool phase4Pass = ApplySupervisorPhase4Gate(p4Zone,zone.bullish,true,phase4Reason,phase4Tag);

   const double aiScore = ComputeAIScore(zone);
   const double minScore = GetEffectiveMinAIScore();
   const int regime = GetCurrentMarketRegime();
   if(regime == REGIME_UNKNOWN)
      return false;
   if(regime == REGIME_TREND && !BiasAllowsDirection(zone.bullish))
      return false;

   const string setupTag = BuildSetupTag(zone,patternPhase,regime);
   string tagReason = "";
   const bool setupTagBlocked = IsSetupTagBlocked(setupTag,tagReason);
   const double setupTagScore = ComputeSetupTagScore(setupTag);

   FVGZone instProbe = zone;
   string instStateTag = "";
   const double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   const bool instReady = EvaluateInstitutionalStates(instProbe,bid,ask,instStateTag);

   double bodyPct = 0.0, volRatio = 1.0, dispRatio = 1.0;
   const bool accelPass = PassAccelerationFilter(zone.bullish,bodyPct,volRatio,dispRatio);
   const double spreadPtsNow = GetCurrentSpreadPoints();
   const double spreadPtsAvg = GetAverageSpreadPoints(12);
   const bool spreadSpike = g_execEngine.IsSpreadSpike(spreadPtsNow,spreadPtsAvg,InpSpreadSpikeFilterMultiplier);
   const double atrPtsNow = MathMax(1.0,ComputeATRPoints(MathMax(6,InpSupervisorP4ATRPeriod)));
   const double rangePtsNow = MathMax(0.0,GetCurrentRangePoints(1));
   const bool volBurst = g_execEngine.IsVolatilityBurst(rangePtsNow,atrPtsNow,InpVolatilityBurstAtrMult);
   double recentRanges[];
   const int compBars = MathMax(3,InpMicroCompressionBars);
   ArrayResize(recentRanges,compBars);
   for(int i = 0; i < compBars; i++)
      recentRanges[i] = GetCurrentRangePoints(i + 1);
   const bool microCompression = g_execEngine.IsMicroCompression(recentRanges,compBars,atrPtsNow,InpMicroCompressionAtrFactor);

   if(spreadSpike)
     {
      if(InpDebugMode)
         PrintFormat("[FILTER] reject %s: spread spike %.1f > avg %.1f * %.2f",
                     zone.name,spreadPtsNow,spreadPtsAvg,MathMax(1.05,InpSpreadSpikeFilterMultiplier));
      return false;
     }
   if(volBurst)
     {
      if(InpDebugMode)
         PrintFormat("[FILTER] reject %s: volatility burst range=%.1f ATR=%.1f mult=%.2f",
                     zone.name,rangePtsNow,atrPtsNow,MathMax(1.0,InpVolatilityBurstAtrMult));
      return false;
     }
   if(microCompression)
     {
      if(InpDebugMode)
         PrintFormat("[FILTER] reject %s: micro-compression bars=%d atrFactor=%.2f",
                     zone.name,compBars,MathMax(0.05,InpMicroCompressionAtrFactor));
      return false;
     }

   SetEntryScoreContext(zone,
                        patternScore,
                        aiScore,
                        regime,
                        instReady,
                        phase2Pass,
                        phase4Pass,
                        accelPass,
                        setupTagScore,
                        setupTagBlocked);

   const Direction dir = zone.bullish ? DIR_BUY : DIR_SELL;
   int entryScore = CalculateEntryScore(dir);
   FxScoreInputs scoreIn;
   scoreIn.regime = regime;
   scoreIn.liquiditySweep = (HasLiquiditySweep(zone.bullish) || zone.sweepWick > 0.0);
   scoreIn.fvgAlign = (zone.bullish == (dir == DIR_BUY)) && !zone.fakeConfirmed;
   scoreIn.htfBiasAlign = BiasAllowsDirection(zone.bullish);
   double violentRatio = 0.0;
   scoreIn.displacementStrong = accelPass || IsViolentDisplacement(zone.bullish,1,violentRatio);
   scoreIn.lowSpread = !spreadSpike;
   scoreIn.sessionBonus = g_execEngine.SessionTimingBonus(TimeCurrent());
   scoreIn.dynamicOffset = GetDynamicConfidenceScoreOffset();
   scoreIn.setupTagScore = setupTagScore;
   scoreIn.probabilisticBoost = g_signalEngine.GetProbabilisticBoost(dispRatio,bodyPct,rangePtsNow / MathMax(atrPtsNow,1.0));
   FxScoreBreakdown scoreOut;
   const int layeredScore = g_execEngine.CalculateEntryScore(scoreIn,scoreOut);
   entryScore = (int)MathRound(MathMax(0.0,MathMin(15.0,entryScore * 0.55 + layeredScore * 0.45)));

   int confirmTh = GetProfileBaseThreshold(false);
   int partialTh = GetProfileBaseThreshold(true);
   if(partialTh > confirmTh)
      partialTh = confirmTh;

   if(InpUseAdaptiveConfirmThreshold)
     {
      const int adaptiveConfirm = GetAdaptiveConfirmThreshold(confirmTh);
      const int delta = adaptiveConfirm - confirmTh;
      confirmTh = adaptiveConfirm;
      partialTh = MathMax(GetProfileBaseThreshold(true),partialTh + delta);
      if(partialTh > confirmTh)
         partialTh = confirmTh;
     }

   confirmTh = g_execEngine.RequiredScore(regime,
                                          confirmTh,
                                          InpRegimeConfirmTrend,
                                          InpRegimeConfirmRange,
                                          InpRegimeConfirmHighVol,
                                          InpRegimeConfirmUnknown);
   partialTh = g_execEngine.PartialScore(regime,
                                         partialTh,
                                         InpRegimePartialTrend,
                                         InpRegimePartialRange,
                                         InpRegimePartialHighVol,
                                         InpRegimePartialUnknown);
   if(partialTh > confirmTh)
      partialTh = confirmTh;

   bool fullSize = true;
   double entryLotScale = 1.0;
   if(InpUseWeightedConfirmation)
     {
      if(entryScore < partialTh)
        {
         if(InpEntryScoreLogs || InpTriggerDecisionLogs)
            PrintFormat("ForceX weighted block (%s): score=%d < partial=%d | conf=%d phase2=%s phase4=%s inst=%s accel=%s ai=%.1f minAI=%.1f pat=%.1f strong=%s",
                        zone.name,entryScore,partialTh,confirmTh,
                        phase2Pass ? "pass" : "fail",
                        phase4Pass ? "pass" : "fail",
                        instReady ? "ready" : "soft",
                        accelPass ? "pass" : "fail",
                        aiScore,minScore,patternScore,strongPass ? "pass" : "fail");
         if(InpDebugMode)
            PrintFormat("[SCORE] %s liq=%.1f fvg=%.1f bias=%.1f disp=%.1f spread=%.1f sess=%.1f dyn=%.1f tag=%.1f prob=%.1f reg=%.1f total=%d",
                        zone.name,
                        scoreOut.liquidity,scoreOut.fvg,scoreOut.htfBias,scoreOut.displacement,
                        scoreOut.spread,scoreOut.session,scoreOut.dynamic,scoreOut.setupTag,scoreOut.probabilistic,
                        scoreOut.regimeAdjust,layeredScore);
         QueueTagEvent("Blocked entry: " + zone.name + " | reason=weighted score " + IntegerToString(entryScore) + " < " + IntegerToString(partialTh));
         return false;
        }

      fullSize = (entryScore >= confirmTh);
      entryLotScale = fullSize ? 1.0 : GetProfilePartialLotFactor();
      if(InpEntryScoreLogs)
         PrintFormat("ForceX weighted entry (%s): score=%d thresholds=%d/%d size=%s accel(body=%.1f vol=%.2f disp=%.2f) setupScore=%.2f setupBlocked=%s",
                     zone.name,entryScore,confirmTh,partialTh,fullSize ? "FULL" : "PARTIAL",
                     bodyPct,volRatio,dispRatio,setupTagScore,setupTagBlocked ? "true" : "false");
     }
   else
     {
      // Legacy fallback if weighted mode disabled.
      if(aiScore < minScore || !phase2Pass || !phase4Pass)
        {
         QueueTagEvent("Blocked entry: " + zone.name + " | reason=legacy hard gate");
         return false;
        }
      entryLotScale = 1.0;
      fullSize = true;
     }

   double requestedLots = InpFixedLots;
   if(InpUseInstitutionalStateModel && zone.fvgDisrespected)
      requestedLots *= 0.5;
   if(!strongPass)
      requestedLots *= 0.85;
   requestedLots *= entryLotScale;
   requestedLots *= GetRegimeLotMultiplier();

   const double fallbackVolume = NormalizeVolume(requestedLots);
   if(fallbackVolume <= 0.0)
      return false;

   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetDeviationInPoints(MathMax(0,GetEffectiveSlippagePoints()));

   MqlTick tick;
   if(!GetFreshTick(tick,reason))
     {
      PrintFormat("ForceX order blocked (%s): %s",zone.name,reason);
      return false;
     }

   const int attempts = MathMax(1,GetEffectiveOrderRetries());
   for(int a = 0; a < attempts; a++)
     {
      reason = "";
      if(!GetFreshTick(tick,reason))
        {
         if(a < attempts - 1 && InpRetryDelayMs > 0)
            Sleep(InpRetryDelayMs);
         continue;
        }

      double sl = 0.0;
      double tp = 0.0;
      if(!BuildOrderLevels(zone.bullish,zone,tick,sl,tp,reason))
        {
         PrintFormat("ForceX order blocked (%s): %s",zone.name,reason);
         return false;
        }

      const double stopPts = MathMax(1.0,MathAbs((zone.bullish ? tick.ask : tick.bid) - sl) / _Point);
      const double regimeRiskPct = g_riskEngine.RegimeRiskPct(regime,
                                                               InpRegimeRiskPctTrend,
                                                               InpRegimeRiskPctRange,
                                                               InpRegimeRiskPctHighVol);
      const double regimeVolRaw = g_riskEngine.ComputeRiskVolume(AccountInfoDouble(ACCOUNT_EQUITY),
                                                                 regimeRiskPct,
                                                                 stopPts,
                                                                 MathMax(0.0000001,ComputePointValuePerLot()),
                                                                 fallbackVolume);
      const double regimeVol = NormalizeVolume(regimeVolRaw);
      const double volume = ComputeRiskSizedVolume(zone.bullish,tick,sl,regimeVol);
      if(volume <= 0.0)
        {
         PrintFormat("ForceX order blocked (%s): volume sizing failed",zone.name);
         return false;
        }

      if(!ValidateMarketModel(zone.bullish,volume,tick,reason))
        {
         PrintFormat("ForceX order blocked (%s): %s",zone.name,reason);
         return false;
        }

      const bool sent = zone.bullish ?
                        g_trade.Buy(volume,_Symbol,0.0,sl,tp,zone.name) :
                        g_trade.Sell(volume,_Symbol,0.0,sl,tp,zone.name);

      if(sent)
        {
         if(InpCrystalOneSignalPerBar && crystalSignalBar > 0)
           {
            if(zone.bullish)
               g_lastCrystalBuyBar = crystalSignalBar;
            else
               g_lastCrystalSellBar = crystalSignalBar;
           }
         g_signalEngine.TryTransition(FLOW_EXECUTED,CurrentExecBarIndex(),"order sent");
         g_signalEngine.TryTransition(FLOW_MANAGING,CurrentExecBarIndex(),"order managing");
         zone.flowState = FLOW_MANAGEMENT_STATE;
         g_tradesToday++;
         if(InpUseSetupTagEngine)
           {
            const string sizeTag = fullSize ? "FULL" : "PARTIAL";
            if(AttachResultDealToTag(setupTag))
               QueueTagEvent("Entry accepted (" + sizeTag + "): " + setupTag);
            else
               QueueTagEvent("Entry accepted (" + sizeTag + ") but tag link missing: " + setupTag);
           }
         return true;
        }

      int rc = (int)g_trade.ResultRetcode();

      if(InpUseInvalidStopsRescue && IsInvalidStopsRetcode(rc))
        {
         const bool rescueSent = zone.bullish ?
                                 g_trade.Buy(volume,_Symbol,0.0,0.0,0.0,zone.name + "_RS") :
                                 g_trade.Sell(volume,_Symbol,0.0,0.0,0.0,zone.name + "_RS");

         if(rescueSent)
           {
            if(InpCrystalOneSignalPerBar && crystalSignalBar > 0)
              {
               if(zone.bullish)
                  g_lastCrystalBuyBar = crystalSignalBar;
               else
                  g_lastCrystalSellBar = crystalSignalBar;
              }
            zone.flowState = FLOW_MANAGEMENT_STATE;
            g_tradesToday++;
            if(InpUseSetupTagEngine)
              {
               const string sizeTag = fullSize ? "FULL" : "PARTIAL";
               if(AttachResultDealToTag(setupTag))
                  QueueTagEvent("Rescue entry accepted (" + sizeTag + "): " + setupTag);
               else
                  QueueTagEvent("Rescue entry accepted (" + sizeTag + ") but tag link missing: " + setupTag);
              }
            string attachReason = "";
            if(!AttachProtectiveStopsAfterEntry(zone.bullish,zone,attachReason))
               PrintFormat("ForceX rescue opened without SL/TP attach (%s): %s",zone.name,attachReason);
            return true;
           }

         rc = (int)g_trade.ResultRetcode();
        }

      if(a < attempts - 1 && (IsRetryRetcode(rc) || IsInvalidStopsRetcode(rc)))
        {
         if(InpRetryDelayMs > 0)
            Sleep(InpRetryDelayMs);
         continue;
        }

      PrintFormat("ForceX order failed (%s): retcode=%d, comment=%s",zone.name,rc,g_trade.ResultRetcodeDescription());
      return false;
     }

   PrintFormat("ForceX order failed (%s): market retries exhausted",zone.name);
   return false;
  }

bool CrossedBullLevel(const double prevBid,const double bid,const double level,const double tol)
  {
   const double triggerLevel = level + tol;
   return (prevBid > triggerLevel && bid <= triggerLevel);
  }

bool CrossedBearLevel(const double prevAsk,const double ask,const double level,const double tol)
  {
   const double triggerLevel = level - tol;
   return (prevAsk < triggerLevel && ask >= triggerLevel);
  }

bool IsScalpContext(const FVGZone &zone)
  {
   if(IsScalpModeActive())
      return true;
   if(!InpUseScalpAutoEntryTF)
      return false;
   if(!InpScalpSenseFromPhase4)
      return false;

   const int minScore = MathMax(0,MathMin(100,InpScalpSenseMinP4Score));
   if(zone.p4Score < minScore)
      return false;

   if(!InpScalpSenseRequirePattern)
      return true;

   if(zone.p4Cplq || zone.p4ThreeDrive || zone.p4Flippy || zone.p4KingType > 0 || zone.p4Qm)
      return true;

   if(GetCurrentMarketRegime() == REGIME_HIGHVOL && zone.liquidityLikelihood >= MathMax(0,InpSupervisorLiqThreshold))
      return true;

   return false;
  }

ENUM_TIMEFRAMES GetEntrySignalTF(const FVGZone &zone)
  {
   if(InpSimpleModeNoGates && InpSimpleOneTimeframe)
      return InpExecutionTF;

   if(!IsScalpContext(zone))
      return InpExecutionTF;

   ENUM_TIMEFRAMES tf = InpScalpEntryTF;
   if(tf == PERIOD_CURRENT || tf <= 0)
      return InpExecutionTF;

   const int execSec = PeriodSeconds(InpExecutionTF);
   const int tfSec = PeriodSeconds(tf);
   if(execSec > 0 && tfSec > 0 && tfSec >= execSec)
      return InpExecutionTF;

   return tf;
  }

bool ConfirmScalpLowerTF(const FVGZone &zone,const double bid,const double ask,const double tol,string &tagOut)
  {
   tagOut = "";
   if(!InpUseScalpAutoEntryTF)
      return true;

   const ENUM_TIMEFRAMES tf = GetEntrySignalTF(zone);
   if(tf == InpExecutionTF)
      return true;

   if(Bars(_Symbol,tf) < 10)
      return false;

   const double o1 = iOpen(_Symbol,tf,1);
   const double c1 = iClose(_Symbol,tf,1);
   const double h1 = iHigh(_Symbol,tf,1);
   const double l1 = iLow(_Symbol,tf,1);
   const double c2 = iClose(_Symbol,tf,2);
   const bool dir = zone.bullish ? (c1 > o1) : (c1 < o1);
   const bool momentum = zone.bullish ? (c1 > iHigh(_Symbol,tf,2)) : (c1 < iLow(_Symbol,tf,2));
   const bool rej = zone.bullish ?
                    (BullRejectionAtLevelTF(zone.lower,tol,tf) || BullRejectionAtLevelTF((zone.lower + zone.upper) * 0.5,tol,tf)) :
                    (BearRejectionAtLevelTF(zone.upper,tol,tf) || BearRejectionAtLevelTF((zone.lower + zone.upper) * 0.5,tol,tf));
   const bool nearZone = zone.bullish ? (bid <= (zone.upper + tol * 2.0)) : (ask >= (zone.lower - tol * 2.0));
   const bool follow = zone.bullish ? (c1 >= c2) : (c1 <= c2);

   int votes = 0;
   if(dir)
      votes++;
   if(momentum)
      votes++;
   if(rej)
      votes++;
   if(nearZone)
      votes++;
   if(follow)
      votes++;

   if(votes < 3)
      return false;

   tagOut = "LTF_" + TimeframeToApiTag(tf);
   return true;
  }

bool BullRejectionAtLevelTF(const double level,const double tol,const ENUM_TIMEFRAMES tf)
  {
   const double o1 = iOpen(_Symbol,tf,1);
   const double c1 = iClose(_Symbol,tf,1);
   const double l1 = iLow(_Symbol,tf,1);
   return (l1 <= (level + tol) && c1 > o1 && c1 > level);
  }

bool BearRejectionAtLevelTF(const double level,const double tol,const ENUM_TIMEFRAMES tf)
  {
   const double o1 = iOpen(_Symbol,tf,1);
   const double c1 = iClose(_Symbol,tf,1);
   const double h1 = iHigh(_Symbol,tf,1);
   return (h1 >= (level - tol) && c1 < o1 && c1 < level);
  }

bool BullRejectionAtLevel(const double level,const double tol)
  {
   return BullRejectionAtLevelTF(level,tol,InpExecutionTF);
  }

bool BearRejectionAtLevel(const double level,const double tol)
  {
   return BearRejectionAtLevelTF(level,tol,InpExecutionTF);
  }

bool EvaluateZoneEntryTrigger(FVGZone &zone,const double bid,const double ask,string &triggerTag,string &blockReason)
  {
   RefreshAdaptiveTriggerModel();
   const int flowBar = CurrentExecBarIndex();
   const double tolBase = MathMax(0,GetAdaptiveTriggerBufferPoints()) * _Point;
   const double tol = tolBase * GetAdaptiveToleranceMultiplier(zone.bullish);
   const double mid = (zone.lower + zone.upper) * 0.5;
   const ENUM_TIMEFRAMES entryTf = GetEntrySignalTF(zone);
   double patternScore = 100.0;
   string patternPhase = "off";

   if(InpEnablePatternModel)
     {
      patternScore = ComputePatternScore(zone,patternPhase);
     }

   triggerTag = "";
   blockReason = "";
   string instSoftTag = "";
   const bool weightedSoft = InpUseWeightedConfirmation;

   if(InpSimpleModeNoGates)
     {
      bool touched = false;
      if(zone.bullish)
        {
         if(InpTriggerLowerTouch && CrossedBullLevel(g_prevBid,bid,zone.lower,tol))
            touched = true;
         if(InpTriggerMidTouch && CrossedBullLevel(g_prevBid,bid,mid,tol))
            touched = true;
         if(InpTriggerUpperTouch && CrossedBullLevel(g_prevBid,bid,zone.upper,tol))
            touched = true;
        }
      else
        {
         if(InpTriggerLowerTouch && CrossedBearLevel(g_prevAsk,ask,zone.lower,tol))
            touched = true;
         if(InpTriggerMidTouch && CrossedBearLevel(g_prevAsk,ask,mid,tol))
            touched = true;
         if(InpTriggerUpperTouch && CrossedBearLevel(g_prevAsk,ask,zone.upper,tol))
            touched = true;
        }

      if(touched)
        {
         g_signalEngine.TryTransition(FLOW_SWEEP_DETECTED,flowBar,"simple zone touch");
         g_signalEngine.TryTransition(FLOW_CONFIRMATION,flowBar,"simple confirmation");
         g_signalEngine.TryTransition(FLOW_ENTRY_READY,flowBar,"simple entry ready");
         triggerTag = "SIMPLE_TOUCH";
         return true;
        }

      blockReason = "simple mode waiting touch";
      return false;
     }

   if(InpUseInstitutionalStateModel)
     {
      string stateTag = "";
      if(!EvaluateInstitutionalStates(zone,bid,ask,stateTag))
        {
         if(InpInstitutionalRequireReady)
           {
            blockReason = "institutional state not ready";
            return false;
           }

         // Soft institutional mode: keep scanning with generic trigger flow.
         instSoftTag = "INST_SOFT";
        }
      else
        {
         bool instHardReady = true;
         if(InpUseAdaptiveTriggerModel)
           {
            const double adaptScore = zone.bullish ? g_adaptModelBullScore : g_adaptModelBearScore;
            const double weakCut = MathMax(0.0,MathMin(100.0,GetAdaptiveWeakScoreEff()));
            if(adaptScore <= weakCut)
              {
               // Weak directional context: require stronger confidence confirmation.
               if(zone.confidence < (GetAdaptiveExecutionMinConfidence() + 5.0))
                 {
                  blockReason = StringFormat("weak adaptive context conf %.1f < %.1f",
                                             zone.confidence,(GetAdaptiveExecutionMinConfidence() + 5.0));
                  return false;
                 }
              }
           }

         triggerTag = stateTag;
         if(zone.fvgRespected)
            triggerTag += "+FVG_RES";
         else if(zone.fvgDisrespected)
            triggerTag += "+FVG_DIS";

         if(InpEnablePatternModel)
            triggerTag += "+P" + IntegerToString((int)MathRound(patternScore));

         if(InpUseAdaptiveTriggerModel)
            triggerTag += "+" + GetAdaptiveStateTag(zone.bullish);

         string phase2Reason = "";
         if(!ApplySupervisorPhase2Gate(zone,zone.bullish,GetEffectiveMinTriggerHits(),true,false,phase2Reason))
           {
            if(weightedSoft)
              {
               instHardReady = false;
               triggerTag = (triggerTag == "" ? "P2_SOFT" : triggerTag + "+P2_SOFT");
              }
            else
              {
               blockReason = "phase2 arm blocked: " + phase2Reason;
               if(InpSupervisorDebugLogs)
                  PrintFormat("ForceX Phase2 arm blocked (%s): %s",zone.name,phase2Reason);
               return false;
              }
           }
         else
            triggerTag += "+A" + IntegerToString((int)MathRound(zone.alignmentScore));

         string phase4Reason = "";
         string phase4Tag = "";
         if(!ApplySupervisorPhase4Gate(zone,zone.bullish,false,phase4Reason,phase4Tag))
           {
            if(weightedSoft)
              {
               instHardReady = false;
               triggerTag = (triggerTag == "" ? "P4_SOFT" : triggerTag + "+P4_SOFT");
              }
            else
              {
               blockReason = "phase4 arm blocked: " + phase4Reason;
               if(InpSupervisorP4Logs)
                  PrintFormat("ForceX Phase4 arm blocked (%s): %s",zone.name,phase4Reason);
               return false;
              }
           }
         else if(StringLen(phase4Tag) > 0)
            triggerTag += "+" + phase4Tag;

         string ltfTag = "";
         if(!ConfirmScalpLowerTF(zone,bid,ask,tol,ltfTag))
           {
            if(weightedSoft)
              {
               instHardReady = false;
               triggerTag = (triggerTag == "" ? "LTF_SOFT" : triggerTag + "+LTF_SOFT");
              }
            else
              {
               blockReason = "lower timeframe confirmation not met";
               return false;
              }
           }
         else if(StringLen(ltfTag) > 0)
            triggerTag += "+" + ltfTag;

         if(instHardReady)
           {
            g_signalEngine.TryTransition(FLOW_SWEEP_DETECTED,flowBar,"institutional sweep");
            g_signalEngine.TryTransition(FLOW_CONFIRMATION,flowBar,"institutional confirmation");
            g_signalEngine.TryTransition(FLOW_ENTRY_READY,flowBar,"institutional entry ready");
            return true;
           }

         if(StringLen(instSoftTag) == 0)
            instSoftTag = "INST_SOFT";
        }
     }

   int hits = 0;
   bool hasPriceTrigger = false;

   if(zone.bullish)
     {
      if(InpTriggerLowerTouch && CrossedBullLevel(g_prevBid,bid,zone.lower,tol))
        {
         hits++;
         hasPriceTrigger = true;
         triggerTag = "LOW";
        }
      if(InpTriggerMidTouch && CrossedBullLevel(g_prevBid,bid,mid,tol))
        {
         hits++;
         hasPriceTrigger = true;
         triggerTag = (triggerTag == "" ? "MID" : triggerTag + "+MID");
        }
      if(InpTriggerUpperTouch && CrossedBullLevel(g_prevBid,bid,zone.upper,tol))
        {
         hits++;
         hasPriceTrigger = true;
         triggerTag = (triggerTag == "" ? "UP" : triggerTag + "+UP");
        }
     }
   else
     {
      if(InpTriggerLowerTouch && CrossedBearLevel(g_prevAsk,ask,zone.lower,tol))
        {
         hits++;
         hasPriceTrigger = true;
         triggerTag = "LOW";
        }
      if(InpTriggerMidTouch && CrossedBearLevel(g_prevAsk,ask,mid,tol))
        {
         hits++;
         hasPriceTrigger = true;
         triggerTag = (triggerTag == "" ? "MID" : triggerTag + "+MID");
        }
      if(InpTriggerUpperTouch && CrossedBearLevel(g_prevAsk,ask,zone.upper,tol))
        {
         hits++;
         hasPriceTrigger = true;
         triggerTag = (triggerTag == "" ? "UP" : triggerTag + "+UP");
        }
     }

   // Keep candle-based triggers tied to a price interaction, so entries stay zone-driven.
   if(hasPriceTrigger && InpTriggerRejectionCandle)
     {
      bool rejHit = false;
      if(zone.bullish)
         rejHit = (BullRejectionAtLevelTF(zone.lower,tol,entryTf) || BullRejectionAtLevelTF(mid,tol,entryTf) || BullRejectionAtLevelTF(zone.upper,tol,entryTf));
      else
         rejHit = (BearRejectionAtLevelTF(zone.lower,tol,entryTf) || BearRejectionAtLevelTF(mid,tol,entryTf) || BearRejectionAtLevelTF(zone.upper,tol,entryTf));

      if(rejHit)
        {
         hits++;
         triggerTag = (triggerTag == "" ? "REJ" : triggerTag + "+REJ");
      }
     }

   if(hasPriceTrigger && InpTriggerMomentumBreak)
     {
      const double c1 = iClose(_Symbol,entryTf,1);
      bool momentum = false;
      if(zone.bullish)
         momentum = (c1 > iHigh(_Symbol,entryTf,2));
      else
         momentum = (c1 < iLow(_Symbol,entryTf,2));

      if(momentum)
        {
         hits++;
         triggerTag = (triggerTag == "" ? "MOM" : triggerTag + "+MOM");
        }
     }

   int requiredHits = GetEffectiveMinTriggerHits();
   requiredHits += GetAdaptiveRequiredHitsShift(zone.bullish);
   if(InpEnablePatternModel && InpPatternDynamicTrigger)
     {
      if(patternScore >= 85.0)
         requiredHits = MathMax(1,requiredHits - 1);
      else if(patternScore < (InpPatternMinScore + 8.0))
         requiredHits++;
     }
   requiredHits = GetSupervisorPhase3RequiredHits(requiredHits);

   if(hasPriceTrigger && InpEnablePatternModel)
     {
      const int pInt = (int)MathRound(patternScore);
      triggerTag = (triggerTag == "" ? "P" + IntegerToString(pInt) : triggerTag + "+P" + IntegerToString(pInt));
     }

   if(hasPriceTrigger && InpUseAdaptiveTriggerModel)
      triggerTag = (triggerTag == "" ? GetAdaptiveStateTag(zone.bullish) : triggerTag + "+" + GetAdaptiveStateTag(zone.bullish));

   if(hasPriceTrigger && StringLen(instSoftTag) > 0)
      triggerTag = (triggerTag == "" ? instSoftTag : instSoftTag + "+" + triggerTag);

   if(hits < requiredHits)
     {
      blockReason = StringFormat("trigger hits %d < required %d",hits,requiredHits);
      return false;
     }

   string phase2Reason = "";
   if(!ApplySupervisorPhase2Gate(zone,zone.bullish,hits,hasPriceTrigger,false,phase2Reason))
     {
      if(weightedSoft)
         triggerTag = (triggerTag == "" ? "P2_SOFT" : triggerTag + "+P2_SOFT");
      else
        {
         blockReason = "phase2 arm blocked: " + phase2Reason;
         if(InpSupervisorDebugLogs)
            PrintFormat("ForceX Phase2 arm blocked (%s): %s",zone.name,phase2Reason);
         return false;
        }
     }
   else
      triggerTag = (triggerTag == "" ? "A" + IntegerToString((int)MathRound(zone.alignmentScore)) :
                    triggerTag + "+A" + IntegerToString((int)MathRound(zone.alignmentScore)));

   string phase4Reason = "";
   string phase4Tag = "";
   if(!ApplySupervisorPhase4Gate(zone,zone.bullish,false,phase4Reason,phase4Tag))
     {
      if(weightedSoft)
         triggerTag = (triggerTag == "" ? "P4_SOFT" : triggerTag + "+P4_SOFT");
      else
        {
         blockReason = "phase4 arm blocked: " + phase4Reason;
         if(InpSupervisorP4Logs)
            PrintFormat("ForceX Phase4 arm blocked (%s): %s",zone.name,phase4Reason);
         return false;
        }
     }
   else if(StringLen(phase4Tag) > 0)
      triggerTag = (triggerTag == "" ? phase4Tag : triggerTag + "+" + phase4Tag);

   string ltfTag = "";
   if(!ConfirmScalpLowerTF(zone,bid,ask,tol,ltfTag))
     {
      if(weightedSoft)
         triggerTag = (triggerTag == "" ? "LTF_SOFT" : triggerTag + "+LTF_SOFT");
      else
        {
         blockReason = "lower timeframe confirmation not met";
         return false;
        }
     }
   else if(StringLen(ltfTag) > 0)
      triggerTag = (triggerTag == "" ? ltfTag : triggerTag + "+" + ltfTag);

   g_signalEngine.TryTransition(FLOW_SWEEP_DETECTED,flowBar,"trigger hits");
   g_signalEngine.TryTransition(FLOW_CONFIRMATION,flowBar,"trigger validation");
   g_signalEngine.TryTransition(FLOW_ENTRY_READY,flowBar,"trigger ready");

   return true;
  }

bool TryStructureFallbackEntry(const double bid,const double ask)
  {
   if(!InpUseStructureFallbackFlow)
      return false;

   const bool bypassBlocks = (InpUseCrystalHeikinSignal && InpUseKUTMilzCleanSetupOnly && InpKUTMilzBypassEntryBlocks);
   if(!bypassBlocks && InpOnePositionAtATime && HasOpenPositionByMagic())
      return false;

   const datetime bar1 = iTime(_Symbol,InpExecutionTF,1);
   if(bar1 <= 0)
      return false;
   if(bar1 == g_lastFallbackSignalBar)
      return false;
   g_lastFallbackSignalBar = bar1;

   const int tfSec = MathMax(1,PeriodSeconds(InpExecutionTF));
   const int cooldownBars = MathMax(1,InpFallbackCooldownBars);
   if(g_lastFallbackEntryBar > 0 && (bar1 - g_lastFallbackEntryBar) < (datetime)(cooldownBars * tfSec))
      return false;

   const int lb = MathMax(3,InpFallbackLookbackBars);
   double hh = -DBL_MAX;
   double ll = DBL_MAX;
   for(int i = 2; i <= lb + 1; i++)
     {
      hh = MathMax(hh,iHigh(_Symbol,InpExecutionTF,i));
      ll = MathMin(ll,iLow(_Symbol,InpExecutionTF,i));
     }
   if(hh <= 0.0 || ll <= 0.0 || hh <= ll)
      return false;

   const double o1 = iOpen(_Symbol,InpExecutionTF,1);
   const double c1 = iClose(_Symbol,InpExecutionTF,1);
   const double h1 = iHigh(_Symbol,InpExecutionTF,1);
   const double l1 = iLow(_Symbol,InpExecutionTF,1);
   const double rng = MathMax(h1 - l1,_Point);
   const double bodyPct = 100.0 * (MathAbs(c1 - o1) / rng);
   if(bodyPct < MathMax(5.0,InpFallbackMinBodyPct))
      return false;

   const double tol = MathMax(0,InpFallbackBreakBufferPoints) * _Point;
   const bool bullBreak = (c1 > (hh + tol)) && (c1 > o1) && (bid > hh);
   const bool bearBreak = (c1 < (ll - tol)) && (c1 < o1) && (ask < ll);
   if(!bullBreak && !bearBreak)
      return false;

   bool bullish = bullBreak;
   if(bullBreak && bearBreak)
      bullish = (MathAbs(c1 - (hh + tol)) >= MathAbs(c1 - (ll - tol)));

   if(InpFallbackRequireBias && !BiasAllowsDirection(bullish))
      return false;

   FVGZone fb;
   fb.name = "ForceX_FB_" + IntegerToString((int)bar1);
   fb.bullish = bullish;
   fb.time1 = bar1;
   fb.time2 = bar1 + (datetime)(MathMax(2,InpFVGRectBars) * tfSec);
   if(bullish)
     {
      fb.lower = MathMin(l1,ll);
      fb.upper = MathMax(h1,c1);
      fb.sweepWick = l1;
      fb.targetLiquidity = c1 + MathMax(rng,MathAbs(c1 - o1)) * 1.25;
      fb.structureLevel = hh;
     }
   else
     {
      fb.lower = MathMin(l1,c1);
      fb.upper = MathMax(h1,hh);
      fb.sweepWick = h1;
      fb.targetLiquidity = c1 - MathMax(rng,MathAbs(c1 - o1)) * 1.25;
      fb.structureLevel = ll;
     }

   fb.gapPoints = MathMax(1.0,(fb.upper - fb.lower) / _Point);
   fb.bodyPct = bodyPct;
   fb.anchorShift = 1;
   fb.active = true;
   fb.traded = false;
   fb.flowState = FLOW_EXECUTION_STATE;
   fb.gateTicks = 0;
   fb.gateBarTime = bar1;
   fb.confidence = MathMax(GetAdaptiveExecutionMinConfidence(),82.0);
   fb.fvgRespected = false;
   fb.fvgDisrespected = false;
   fb.doubleSweep = false;
   fb.gapAtr = 0.0;
   fb.qualityScore = 0.0;
   fb.qualityTier = 0;
   fb.fakeConfirmed = false;
   fb.liquidityLikelihood = 0.0;
   fb.alignmentScore = 0.0;
   fb.bosAligned = false;
   fb.chochAligned = false;
   fb.ageBars = 0;
   fb.p4Sgb = false;
   fb.p4Flippy = false;
   fb.p4Compression = false;
   fb.p4Cplq = false;
   fb.p4ThreeDrive = false;
   fb.p4Qm = false;
   fb.p4KingType = 0;
   fb.p4PatternQuality = 0.0;
   fb.p4Score = 0.0;
   fb.memDisplacement = false;
   fb.memUnfilled = false;
   fb.memStructure = false;
   fb.memLiquidity = false;
   fb.memScore = 0.0;

   if(!bypassBlocks)
     {
      if(!CanOpenTrade(bullish))
         return false;
     }
   else
     {
      if(InpTradeOnlyV75Symbols && !g_isV75 && !IsCrash900ProfileActive())
         return false;
      if(bullish && !InpAllowBuy)
         return false;
      if(!bullish && !InpAllowSell)
         return false;
     }

   g_signalEngine.TryTransition(FLOW_SWEEP_DETECTED,CurrentExecBarIndex(),"fallback sweep");
   g_signalEngine.TryTransition(FLOW_CONFIRMATION,CurrentExecBarIndex(),"fallback confirmation");
   g_signalEngine.TryTransition(FLOW_ENTRY_READY,CurrentExecBarIndex(),"fallback ready");
   const bool traded = ExecuteMarketOrder(fb);
   if(traded)
     {
      g_lastFallbackEntryBar = bar1;
      QueueTagEvent("Entry accepted: FALLBACK_STRUCT_" + string(bullish ? "BUY" : "SELL"));
      PrintFormat("ForceX fallback structure entry fired: %s",bullish ? "BUY" : "SELL");
      return true;
     }

   return false;
  }

void ManageFVGZonesAndEntries()
  {
   const int invalidationPoints = GetEffectiveInvalidationPoints();
   const double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   const datetime diagBar = iTime(_Symbol,InpExecutionTF,1);
   const bool diagThisBar = (InpTriggerDecisionLogs && diagBar > 0 && diagBar != g_lastTriggerDiagBar);
   bool diagPrinted = false;
   if(diagThisBar)
      g_lastTriggerDiagBar = diagBar;

   if(IsMasterExecutionMode())
     {
      g_prevBid = bid;
      g_prevAsk = ask;
      return;
     }

   if(g_prevBid <= 0.0 || g_prevAsk <= 0.0)
     {
      g_prevBid = bid;
      g_prevAsk = ask;
      return;
     }

   for(int i = ArraySize(g_zones) - 1; i >= 0; i--)
     {
      if(ObjectFind(0,g_zones[i].name) < 0)
        {
         RemoveZoneByIndex(i,false);
         continue;
        }

      if(TimeCurrent() >= g_zones[i].time2)
        {
         RemoveZoneByIndex(i,true);
         continue;
        }

      if(g_zones[i].bullish)
        {
         if(bid < (g_zones[i].lower - invalidationPoints * _Point))
           {
            RemoveZoneByIndex(i,true);
            continue;
           }
        }
      else
        {
         if(ask > (g_zones[i].upper + invalidationPoints * _Point))
           {
            RemoveZoneByIndex(i,true);
            continue;
           }
        }

      if(IsV75FVGInversionSell(g_zones[i]))
        {
         FVGZone inv = g_zones[i];
         inv.bullish = false;
         inv.flowState = FLOW_EXECUTION_STATE;
         g_signalEngine.TryTransition(FLOW_SWEEP_DETECTED,CurrentExecBarIndex(),"inversion sweep");
         g_signalEngine.TryTransition(FLOW_CONFIRMATION,CurrentExecBarIndex(),"inversion confirmation");
         g_signalEngine.TryTransition(FLOW_ENTRY_READY,CurrentExecBarIndex(),"inversion ready");
         inv.confidence = 100.0;
         inv.sweepWick = iHigh(_Symbol,InpExecutionTF,1);
         inv.targetLiquidity = iLow(_Symbol,InpExecutionTF,2);
         const bool invTraded = ExecuteMarketOrder(inv);
         if(invTraded && InpRemoveZoneAfterTouch)
           {
            PrintFormat("ForceX V75 inversion sell fired (%s)",g_zones[i].name);
            RemoveZoneByIndex(i,true);
            continue;
           }
        }

      string triggerTag = "";
      string blockReason = "";
      const bool triggered = EvaluateZoneEntryTrigger(g_zones[i],bid,ask,triggerTag,blockReason);
      if(triggered)
        {
         g_signalEngine.TryTransition(FLOW_ENTRY_READY,CurrentExecBarIndex(),"zone trigger ready");
         const bool traded = ExecuteMarketOrder(g_zones[i]);

         if(traded && InpRemoveZoneAfterTouch)
           {
            PrintFormat("ForceX trigger fired (%s): %s",g_zones[i].name,triggerTag);
            RemoveZoneByIndex(i,true);
            continue;
           }
        }
      else if(diagThisBar && !diagPrinted && StringLen(blockReason) > 0)
        {
         PrintFormat("ForceX trigger wait (%s): %s",g_zones[i].name,blockReason);
         QueueTagEvent("Blocked entry: " + g_zones[i].name + " | reason=" + blockReason);
         diagPrinted = true;
        }
     }

   int activeZonesLeft = 0;
   for(int z = 0; z < ArraySize(g_zones); z++)
      if(g_zones[z].active)
         activeZonesLeft++;

   if(activeZonesLeft <= 0)
      TryStructureFallbackEntry(bid,ask);

   g_prevBid = bid;
   g_prevAsk = ask;
  }

// Structure engine placeholder for HH/HL/LH/LL and BOS/CHoCH extensions.
void UpdateStructureEngine()
  {
   if(!InpEnableStructureLabels)
     {
      DeleteObjectsByPrefix(STRUCT_PREFIX);
      return;
     }

   if(g_zzHandle == INVALID_HANDLE)
     {
      if(!InitStructureEngine())
         return;
     }

   datetime barState = g_lastStructureBarTime;
   const bool isNewStructureBar = IsNewBar(g_structureTF,barState);
   if(!isNewStructureBar && CountObjectsByPrefix(g_structureTag) > 0)
      return;
   g_lastStructureBarTime = barState;

   const int bars = Bars(_Symbol,g_structureTF);
   if(bars < InpZZDepth + InpZZBackstep + 10)
      return;

   const int lookback = MathMax(50,InpStructureLookbackBars);
   const int count = MathMin(bars,lookback);

   double zz[];
   ArraySetAsSeries(zz,true);
   const int copied = CopyBuffer(g_zzHandle,0,0,count,zz);
   if(copied <= 0)
      return;

   DeleteObjectsByPrefix(g_structureTag);

   int lastHighIndex = -1;
   double lastHighPrice = 0.0;
   int lastLowIndex = -1;
   double lastLowPrice = 0.0;

   int prevSwingIndex = -1;
   double prevSwingPrice = 0.0;

   const double yOffset = InpStructureLabelOffsetPoints * _Point;
   const double matchTolerance = MathMax(_Point,_Point * 2.0);

   for(int i = copied - 1; i >= 0; i--)
     {
      if(zz[i] == 0.0)
         continue;

      const double currPrice = zz[i];
      const datetime currTime = iTime(_Symbol,g_structureTF,i);
      if(currTime <= 0)
         continue;

      const double barHigh = iHigh(_Symbol,g_structureTF,i);
      const double barLow = iLow(_Symbol,g_structureTF,i);
      bool isHigh = (MathAbs(barHigh - currPrice) <= matchTolerance);
      bool isLow  = (MathAbs(barLow - currPrice) <= matchTolerance);

      if(!isHigh && !isLow)
        {
         const double dHigh = MathAbs(barHigh - currPrice);
         const double dLow  = MathAbs(barLow - currPrice);
         isHigh = (dHigh < dLow);
         isLow  = !isHigh;
        }

      string label = "";

      if(isHigh)
        {
         if(lastHighIndex != -1)
            label = (currPrice > lastHighPrice) ? "HH" : "LH";
         lastHighIndex = i;
         lastHighPrice = currPrice;
        }
      else if(isLow)
        {
         if(lastLowIndex != -1)
            label = (currPrice < lastLowPrice) ? "LL" : "HL";
         lastLowIndex = i;
         lastLowPrice = currPrice;
        }

      if(prevSwingIndex != -1)
        {
         const datetime prevTime = iTime(_Symbol,g_structureTF,prevSwingIndex);
         if(prevTime > 0)
           {
            const string lineName = g_structureTag + "Line_" + IntegerToString((int)currTime);
            ObjectCreate(0,lineName,OBJ_TREND,0,prevTime,prevSwingPrice,currTime,currPrice);
            ObjectSetInteger(0,lineName,OBJPROP_COLOR,InpStructureLineColor);
            ObjectSetInteger(0,lineName,OBJPROP_WIDTH,1);
            ObjectSetInteger(0,lineName,OBJPROP_RAY_RIGHT,false);
            ObjectSetInteger(0,lineName,OBJPROP_RAY_LEFT,false);
            ObjectSetInteger(0,lineName,OBJPROP_SELECTABLE,false);
            ObjectSetInteger(0,lineName,OBJPROP_HIDDEN,true);
           }
        }

      prevSwingIndex = i;
      prevSwingPrice = currPrice;

      if(label != "")
        {
         const string labelName = g_structureTag + "Label_" + IntegerToString((int)currTime);
         const double yPrice = currPrice + (isHigh ? yOffset : -yOffset);
         ObjectCreate(0,labelName,OBJ_TEXT,0,currTime,yPrice);
         ObjectSetString(0,labelName,OBJPROP_TEXT,label);
         ObjectSetString(0,labelName,OBJPROP_FONT,"Arial");
         ObjectSetInteger(0,labelName,OBJPROP_FONTSIZE,InpStructureFontSize);
         ObjectSetInteger(0,labelName,OBJPROP_COLOR,InpStructureTextColor);
         ObjectSetInteger(0,labelName,OBJPROP_ANCHOR,isHigh ? ANCHOR_LOWER : ANCHOR_UPPER);
         ObjectSetInteger(0,labelName,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,labelName,OBJPROP_HIDDEN,true);
        }
     }
  }

// Liquidity engine placeholder for EQH/EQL and pool mapping extensions.
void UpdateLiquidityEngine()
  {
  }

// Visual map placeholder for institutional HUD extensions.
void UpdateVisualMap()
  {
  }

int OnInit()
  {
   g_trade.SetExpertMagicNumber(InpMagic);
   DetectSymbolProfile();
   ParseSessionTimes();
   ResolveModeProfile();
   RefreshAdaptiveTriggerModel();
   if(InpUseCrystalHeikinSignal && !InpEnableStructureLabels)
     {
      Print("ForceX Crystal mode requires InpEnableStructureLabels=true (ZigZag on).");
      return(INIT_FAILED);
     }
   if(!InitCrystalSignalEngine())
      return(INIT_FAILED);

   PrintFormat("ForceX active mode profile: %s",g_modeProfile);
   if(InpSimpleModeNoGates)
      PrintFormat("ForceX SIMPLE MODE: no-gates=%s one-tf=%s execTF=%s",
                  InpSimpleModeNoGates ? "true" : "false",
                  InpSimpleOneTimeframe ? "true" : "false",
                  TimeframeToApiTag(InpExecutionTF));

   if(InpEnableLossLearning && InpLossLearnPersistState)
     {
      if(InpLossLearnResetOnInit)
        {
         ResetLossLearningState();
         Print("ForceX LossLearning state reset on init");
        }

      if(LoadLossLearningState())
         PrintFormat("ForceX LossLearning restored: conf=%.1f trigBuf=%d tickDelay=%d violent=%.2f sweepSL=%d streak=%d events=%d",
                     GetAdaptiveExecutionMinConfidence(),
                     GetAdaptiveTriggerBufferPoints(),
                     GetAdaptiveTriggerTickDelay(),
                     GetAdaptiveViolenceMultiplier(),
                     GetAdaptiveSweepSLExtraPoints(),
                     g_lossStreak,
                     g_lossLearnEvents);
     }

   if(InpEnableV75Profile && g_isV75)
     {
      PrintFormat("ForceX V75 profile active on %s (1s=%s). gap=%d spread=%d slippage=%d retries=%d",
                  _Symbol,
                  g_isV751s ? "true" : "false",
                  GetEffectiveMinGapPoints(),
                  GetEffectiveMaxSpreadPoints(),
                  GetEffectiveSlippagePoints(),
                  GetEffectiveOrderRetries());
     }

   if(InpTradeOnlyV75Symbols && !g_isV75 && !IsCrash900ProfileActive())
      PrintFormat("ForceX trading disabled on %s because InpTradeOnlyV75Symbols=true",_Symbol);

   if(IsCrash900ProfileActive())
      PrintFormat("ForceX Crash900 profile active on %s (buy-only, max-bars=%d)",
                  _Symbol,MathMax(1,InpCrash900MaxPositionBars));

   if(InpEnablePatternModel)
      PrintFormat("ForceX PatternModel on: min=%.1f lookback=%d dynamicTrigger=%s",
                  InpPatternMinScore,InpPatternLookbackBars,InpPatternDynamicTrigger ? "true" : "false");

   if(InpUseInstitutionalStateModel)
      PrintFormat("ForceX Institutional execution on: strictReady=%s conf>=%.1f tickDelay=%d execTick=%d wickPts=%d",
                  InpInstitutionalRequireReady ? "true" : "false",
                  GetAdaptiveExecutionMinConfidence(),
                  GetAdaptiveTriggerTickDelay(),
                  InpTriggerExecuteTick,
                  InpWickSweepMinPoints);

   if(InpUseV75DualSMCExecution)
      PrintFormat("ForceX V75 Dual-SMC on: violent>=%.2fx(%d) RR>=%.2f sweepSL=%d invBody=%.1f%%",
                  GetAdaptiveViolenceMultiplier(),
                  InpV75ViolenceLookback,
                  InpV75MinRR,
                  GetAdaptiveSweepSLExtraPoints(),
                  InpV75InvalidationBodyPct);

   if(InpEnableLossLearning)
      PrintFormat("ForceX LossLearning on: minLoss=%.2f confStep=%.2f trigStep=%d tickStep=%d violentStep=%.2f sweepStep=%d",
                  InpLossLearnMinLossUSD,
                  InpLossLearnConfidenceStep,
                  InpLossLearnTriggerBufStep,
                  InpLossLearnTickDelayStep,
                  InpLossLearnViolenceStep,
                  InpLossLearnSweepSLStep);

   if(IsStrongModeActive())
      PrintFormat("ForceX StrongMode on: minAIScore=%d maxSpread=%d retest=%s trail=%s",
                  InpStrongMinAIScore,
                  InpStrongMaxSpreadPoints,
                  InpStrongRequireRetestCandle ? "true" : "false",
                  InpUseTrailingStop ? "true" : "false");

   if(IsScalpModeActive())
      PrintFormat("ForceX ScalpMode on: RR=%.2f SLbuf=%d minHits=%d BE=%d trailStart=%d trailDist=%d",
                  GetEffectiveRiskReward(),
                  GetEffectiveSLBufferPoints(),
                  GetEffectiveMinTriggerHits(),
                  GetEffectiveBreakEvenTriggerPoints(),
                  GetEffectiveTrailingStartPoints(),
                  GetEffectiveTrailingDistancePoints());

   PrintFormat("ForceX ExitGuard: suspendClose=%s oppositeStrongClose=%s usdSweepWithTP=%s transitionClose=%s oppositeFVGClose=%s respectSetSLTP=%s firstMoveBE(min/trig)=%d/%d trailAssistFloor=%d",
               InpUseInstitutionalSuspendClose ? "true" : "false",
               InpUseOppositeStrongCandleClose ? "true" : "false",
               InpUseUSDPerTradeSweepWithTP ? "true" : "false",
               InpUseTransitionSuspendClose ? "true" : "false",
               InpUseOppositeFVGSuspendClose ? "true" : "false",
               InpRespectSetSLTPForSoftCloses ? "true" : "false",
               MathMax(1,InpFirstMoveBreakEvenMinPoints),
               MathMax(1,InpFirstMoveBreakEvenTriggerPoints),
               MathMax(1,InpFirstMoveTrailAssistMinPoints));

   PrintFormat("ForceX WeightedEntry: enabled=%s confirm=%d partial=%d lotFactor=%.2f adaptive=%s accel=%s RR1Manage=%s profileTh=%s",
               InpUseWeightedConfirmation ? "true" : "false",
               GetProfileBaseThreshold(false),
               GetProfileBaseThreshold(true),
               GetProfilePartialLotFactor(),
               InpUseAdaptiveConfirmThreshold ? "true" : "false",
               InpUseEntryAccelerationFilter ? "true" : "false",
               InpUseRR1PartialAndBE ? "true" : "false",
               InpUseProfileSpecificScoreThresholds ? "true" : "false");
   PrintFormat("ForceX StrictFlow: timeoutBars=%d spreadSpikeMult=%.2f biasFlipReset=%s",
               MathMax(2,InpFlowStateTimeoutBars),
               MathMax(1.05,InpFlowSpreadSpikeMultiplier),
               InpFlowResetOnBiasFlip ? "true" : "false");
   PrintFormat("ForceX ProRisk: dailyDD=%.2f%% consecLossPause=%d/%d globalDD=%.2f%%",
               MathMax(0.0,InpDailyDrawdownLimitPct),
               MathMax(1,InpConsecLossPauseCount),
               MathMax(1,InpConsecLossPauseBars),
               MathMax(0.0,MaxEquityDrawdownPercent));
   PrintFormat("ForceX RegimeTable: score(T/R/HV/U)=%d/%d/%d/%d partial=%d/%d/%d/%d risk%%=%.2f/%.2f/%.2f",
               MathMax(1,InpRegimeConfirmTrend),
               MathMax(1,InpRegimeConfirmRange),
               MathMax(1,InpRegimeConfirmHighVol),
               MathMax(1,InpRegimeConfirmUnknown),
               MathMax(1,InpRegimePartialTrend),
               MathMax(1,InpRegimePartialRange),
               MathMax(1,InpRegimePartialHighVol),
               MathMax(1,InpRegimePartialUnknown),
               MathMax(0.01,InpRegimeRiskPctTrend),
               MathMax(0.01,InpRegimeRiskPctRange),
               MathMax(0.01,InpRegimeRiskPctHighVol));

   if(InpUseScalpAutoEntryTF)
      PrintFormat("ForceX ScalpOrchestrator: scalpTF=%s senseP4=%s p4Min=%d requirePattern=%s",
                  TimeframeToApiTag(InpScalpEntryTF),
                  InpScalpSenseFromPhase4 ? "true" : "false",
                  MathMax(0,MathMin(100,InpScalpSenseMinP4Score)),
                  InpScalpSenseRequirePattern ? "true" : "false");

   if(InpUseAdaptiveTriggerModel)
      PrintFormat("ForceX AdaptiveTrigger on: profile=%s lookback=%d strong>=%.1f weak<=%.1f hitsShift=%d tolShift=%.1f%% tickShift=%d",
                  (IsV75ProfileActive() ? (g_isV751s ? "V75_1S" : "V75") : "DEFAULT"),
                  GetAdaptiveLookbackBarsEff(),
                  GetAdaptiveStrongScoreEff(),
                  GetAdaptiveWeakScoreEff(),
                  GetAdaptiveMaxHitsShiftEff(),
                  GetAdaptiveToleranceShiftPctEff(),
                  GetAdaptiveTickDelayShiftEff());

   if(InpProtectManualSLTPTrades)
      PrintFormat("ForceX Manual SL/TP protection on: tag='%s' requireBoth=%s commentOnly=%s",
                  InpManualTradeCommentTag,
                  InpManualProtectRequireBothSLTP ? "true" : "false",
                  InpManualProtectByCommentOnly ? "true" : "false");

   if(InpUseStructureFallbackFlow)
      PrintFormat("ForceX Fallback flow on: lookback=%d body>=%.1f%% breakBuf=%d cooldown=%d bias=%s",
                  MathMax(3,InpFallbackLookbackBars),
                  MathMax(5.0,InpFallbackMinBodyPct),
                  MathMax(0,InpFallbackBreakBufferPoints),
                  MathMax(1,InpFallbackCooldownBars),
                  InpFallbackRequireBias ? "true" : "false");

   if(InpUseRegimeMode)
      PrintFormat("ForceX RegimeMode on: lookback=%d trend>=%.1f%% highVol>=%.2fx",
                  InpRegimeLookbackBars,InpRegimeTrendThresholdPct,InpRegimeHighVolRatio);

   if(InpUseDynamicConfidence)
      PrintFormat("ForceX DynamicConfidence on: deals=%d tighten<%.2f relax>%.2f",
                  InpDynamicConfidenceDeals,InpDynamicConfTightenWinRate,InpDynamicConfRelaxWinRate);

   if(InpUseTimeStopExit)
      PrintFormat("ForceX TimeStop on: soft=%d bars hard=%d bars minProgress=%.1f pts",
                  InpTimeStopBars,InpTimeStopHardLossBars,InpTimeStopMinProgressPts);
   if(InpUseNoProgressExit)
      PrintFormat("ForceX NoProgress exit on: bars=%d minProgress=%.1f pts",
                  MathMax(1,InpNoProgressExitBars),MathMax(0.0,InpNoProgressMinProgressPts));
   if(InpUseCrystalHeikinSignal)
      PrintFormat("ForceX Crystal signal on: indicator='%s' tf=%s buy/sell buffers=%d/%d mode=%s shift=%d confirmCandles=%d",
                  InpCrystalIndicatorPath,
                  TimeframeToApiTag(g_crystalTF),
                  InpCrystalBuyBuffer,
                  InpCrystalSellBuffer,
                  InpCrystalSignalUseNonEmpty ? "non-empty" : "positive",
                  MathMax(1,InpCrystalSignalShift),
                  MathMax(0,InpCrystalConfirmCandles));
   if(InpUseKUTMilzCleanSetupOnly)
      PrintFormat("ForceX KUTMilz clean mode on: bypassBlocks=%s exitOpposite=%s swingWing=%d lookback=%d",
                  InpKUTMilzBypassEntryBlocks ? "true" : "false",
                  InpKUTMilzExitOnOppositeCandle ? "true" : "false",
                  MathMax(2,InpKUTMilzSwingWing),
                  MathMax(60,InpKUTMilzSwingLookback));
   if(IsMasterExecutionMode())
      Print("ForceX KUTMilz MASTER override on: candle-close execution bypassing entry filters");

   if(InpUseAtrRiskSizing)
      PrintFormat("ForceX ATR risk sizing on: risk=%.2f%% atrPeriod=%d floor=%.2f",
                  InpRiskPerTradePct,InpAtrRiskPeriod,InpAtrStopFloorMult);

   if(InpUseSetupTagEngine)
      PrintFormat("ForceX SetupTag engine on: minSamples=%d maxConsecLosses=%d cooldownBars=%d logs=%s",
                  MathMax(1,InpTagMinSamples),
                  MathMax(1,InpTagMaxConsecLosses),
                  MathMax(1,InpTagCooldownBars),
                  InpTagDecisionLogs ? "true" : "false");

   if(InpUseSupervisorPhase2)
      PrintFormat("ForceX Supervisor Phase2 on: arm>=%.1f enter>=%.1f cancel<%.1f ATR=%d minGapATR=%.2f fakeBars=%d fakeFill>=%.0f%% blockFake=%s liqReq=%s liq>=%.1f",
                  InpSupervisorArmThreshold,
                  InpSupervisorEnterThreshold,
                  InpSupervisorCancelThreshold,
                  MathMax(2,InpSupervisorATRPeriod),
                  MathMax(0.01,InpSupervisorMinGapATR),
                  MathMax(1,InpSupervisorFakeConfirmBars),
                  MathMax(1.0,MathMin(100.0,InpSupervisorFakeFillPct)),
                  InpSupervisorBlockFakeFVG ? "true" : "false",
                  InpSupervisorRequireLiqLikelihood ? "true" : "false",
                  MathMax(0.0,MathMin(100.0,InpSupervisorLiqThreshold)));

   if(InpUseSupervisorPhase3)
      PrintFormat("ForceX Supervisor Phase3 on: BOSw=%.1f CHOCHw=%.1f reqEntryBOSCHOCH=%s reqFlowBOSCHOCH=%s range(arm/enter/hits)=%d/%d/%d highVol(arm/enter/hits)=%d/%d/%d",
                  MathMax(0.0,MathMin(50.0,InpSupervisorBosWeight)),
                  MathMax(0.0,MathMin(60.0,InpSupervisorChochWeight)),
                  InpSupervisorRequireBosOrChochEntry ? "true" : "false",
                  InpSupervisorRequireBosOrChochFlow ? "true" : "false",
                  MathMax(0,InpSupervisorRangeArmBoost),
                  MathMax(0,InpSupervisorRangeEnterBoost),
                  MathMax(0,InpSupervisorRangeHitsAdd),
                  MathMax(0,InpSupervisorHighVolArmBoost),
                  MathMax(0,InpSupervisorHighVolEnterBoost),
                  MathMax(0,InpSupervisorHighVolHitsAdd));

   if(InpUseSupervisorPhase4)
      PrintFormat("ForceX Supervisor Phase4 on: arm=%d enter=%d cancel=%d htfOverride=%d atr=%d spread(V75/V751s)=%d/%d spikeATR(V75/V751s)=%.2f/%.2f",
                  MathMax(0,MathMin(100,InpSupervisorP4ArmThreshold)),
                  MathMax(0,MathMin(100,InpSupervisorP4EnterThreshold)),
                  MathMax(0,MathMin(100,InpSupervisorP4CancelThreshold)),
                  MathMax(0,MathMin(100,InpSupervisorP4HTFOverrideScore)),
                  MathMax(2,InpSupervisorP4ATRPeriod),
                  MathMax(1,InpSupervisorP4SpreadMaxV75),
                  MathMax(1,InpSupervisorP4SpreadMaxV751s),
                  MathMax(0.5,InpSupervisorP4VolSpikeAtrV75),
                  MathMax(0.5,InpSupervisorP4VolSpikeAtrV751s));

   if(InpUseSupervisorMemoryLayer)
      PrintFormat("ForceX MemoryLayer on: lookback=%d minDispATR=%.2f volFilter=%s volRatio>=%.2f blend=%.1f%% minScore=%d liqRequired=%s",
                  MathMax(20,MathMin(600,InpMemoryLookbackBars)),
                  MathMax(0.1,InpMemoryMinCandleSizeATR),
                  InpMemoryFilterByVolume ? "true" : "false",
                  MathMax(1.0,InpMemoryMinVolumeRatio),
                  MathMax(0.0,MathMin(60.0,InpMemoryBlendPct)),
                  MathMax(0,MathMin(100,InpMemoryMinScore)),
                  InpMemoryRequireLiquiditySweep ? "true" : "false");

   if(InpUseUSDPerTradeSweep || InpUseUSDBasketSweep)
      PrintFormat("ForceX USD sweep on: tradeTP=%.2f tradeSL=%.2f basketTP=%.2f basketSL=%.2f",
                  InpUSDTakeProfitPerTrade,
                  InpUSDLossCutPerTrade,
                  InpUSDBasketTakeProfit,
                  InpUSDBasketLossCut);

   if(InpDeleteZonesOnInit)
      ObjectsDeleteAll(0,FVG_PREFIX);

   RefreshDailyState();
   ScanAndBuildFVGs();
   InitStructureEngine();
   UpdateStructureEngine();

   if(InpEnableBackendTelemetry)
     {
      EventSetTimer(MathMax(1,InpBackendTelemetryEverySec));
      SendBackendTelemetry(true);
      PrintFormat("ForceX Telemetry enabled -> %s (every %ds)",TrimBackendBase(InpBackendApiBase),MathMax(1,InpBackendTelemetryEverySec));
     }

   if(CountOpenPositionsForMagicSymbol(InpMagic,_Symbol) > 0)
     {
      const int barIdx = CurrentExecBarIndex();
      g_signalEngine.TryTransition(FLOW_SWEEP_DETECTED,barIdx,"init recover");
      g_signalEngine.TryTransition(FLOW_CONFIRMATION,barIdx,"init recover");
      g_signalEngine.TryTransition(FLOW_ENTRY_READY,barIdx,"init recover");
      g_signalEngine.TryTransition(FLOW_EXECUTED,barIdx,"init recover");
      g_signalEngine.TryTransition(FLOW_MANAGING,barIdx,"init recover");
     }

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   SaveLossLearningState();
   EventKillTimer();
   ReleaseCrystalSignalEngine();
   ReleaseStructureEngine();
  }

void OnTimer()
  {
   SendBackendTelemetry(false);
  }

void OnTick()
  {
   RefreshDailyState();
   UpdateFlowMachineGuards();
   if(g_riskEngine.IsGlobalKilled() && !IsMasterExecutionMode())
     {
      CloseAllMagicPositionsByUSD("GLOBAL_KILL_SWITCH");
      return;
     }
   if(InpUseRegimeMode)
      GetCurrentMarketRegime();
   if(InpUseDynamicConfidence)
      RefreshDynamicConfidenceOffset();

   if(CountFVGObjects() == 0 && ArraySize(g_zones) > 0)
      ArrayResize(g_zones,0);

   datetime barState = g_lastExecBarTime;
   if(IsNewBar(InpExecutionTF,barState))
     {
      g_lastExecBarTime = barState;
      ScanAndBuildFVGs();
      RefreshAdaptiveTriggerModel();
      g_signalEngine.UpdateLockedSwings(_Symbol,InpExecutionTF,MathMax(60,InpStructureLookbackBars),3);
     }

   UpdateStructureEngine();
   UpdateLiquidityEngine();
   ManageOpenPositions();
   if(IsMasterExecutionMode())
      TryMasterExecutionEntryOnBarClose();
   ManageFVGZonesAndEntries();
   UpdateVisualMap();
   SendBackendTelemetry(false);
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   if(trans.deal == 0)
      return;

   if(!HistorySelect(TimeCurrent() - 86400 * 31,TimeCurrent()))
      HistorySelect(0,TimeCurrent());

   if((long)HistoryDealGetInteger(trans.deal,DEAL_MAGIC) == InpMagic &&
      HistoryDealGetString(trans.deal,DEAL_SYMBOL) == _Symbol &&
      (long)HistoryDealGetInteger(trans.deal,DEAL_ENTRY) == DEAL_ENTRY_OUT)
     {
      const double pnl = HistoryDealGetDouble(trans.deal,DEAL_PROFIT) +
                         HistoryDealGetDouble(trans.deal,DEAL_SWAP) +
                         HistoryDealGetDouble(trans.deal,DEAL_COMMISSION);
      g_riskEngine.OnClosedDeal(pnl,
                                CurrentExecBarIndex(),
                                MathMax(1,InpConsecLossPauseCount),
                                MathMax(1,InpConsecLossPauseBars));
      RegisterPerformanceFromDeal(trans.deal);
      LogPerformanceSummaryIfDue();
      g_signalEngine.TryTransition(FLOW_EXITED,CurrentExecBarIndex(),"deal close");
      g_signalEngine.TryTransition(FLOW_IDLE,CurrentExecBarIndex(),"ready after close");
     }

   if(InpEnableLossLearning)
      LearnFromLosingDeal(trans.deal);
   if(InpUseSetupTagEngine)
      UpdateSetupTagOutcomeFromDeal(trans.deal);
   if(InpUseDynamicConfidence)
      RefreshDynamicConfidenceOffset();
   SendBackendTelemetry(true);
  }
