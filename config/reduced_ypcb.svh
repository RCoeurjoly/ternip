localparam int D = 64;
localparam int TmatmulParallelism = 8;
localparam int VectorParallelism = 4;
localparam int LutParallelism = 1;

localparam int FixedPointPrecision = 8;
localparam int FixedPointExponent = -3;

parameter mul_impl_e MultiplicationImplementation = MUL_BSG;
parameter div_impl_e DivisionImplementation = DIV_BSG;

localparam bit UseHardSigmoid = 1;

localparam int BatchSize = 1;

localparam int NumVectorRegisters = 8;
localparam int ImmediateWidth = 16;
localparam int DdrAddressWidth = 64;
localparam int InstructionWidth = 128;

localparam int DdrDataWidth = 128;
localparam int InstrFetchWidth = 128;
localparam int CoreInterconnectNumStages = 4;

localparam real DramMaxBytesPerSecond = 10.0**12;
localparam real ClockPeriod = 10.0 * 10.0**-9;
