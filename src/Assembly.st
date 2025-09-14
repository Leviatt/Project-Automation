PROGRAM Assembly

(* ====== RAW INPUTS (located) ====== *)
VAR
  IX_Start        AT %IX100.0 : BOOL;
  IX_Stop         AT %IX100.1 : BOOL;
  IX_LidAtPlace   AT %IX100.2 : BOOL;
  IX_BaseAtPlace  AT %IX100.3 : BOOL;
  IX_LidClamped   AT %IX100.4 : BOOL;
  IX_BaseClamped  AT %IX100.5 : BOOL;
  IX_ZMoving      AT %IX100.6 : BOOL;
  IX_XMoving      AT %IX100.7 : BOOL;
  IX_BladeLimit   AT %IX101.0 : BOOL;
  IX_PartLeaving  AT %IX101.1 : BOOL;
  IX_ItemDetected AT %IX101.2 : BOOL;
END_VAR

(* ====== RAW OUTPUTS (located) ====== *)
VAR
  QX_RunLamp   AT %QX100.0 : BOOL;
  QX_AlarmLamp AT %QX100.1 : BOOL;
  QX_LidsConv  AT %QX100.2 : BOOL;
  QX_BasesConv AT %QX100.3 : BOOL;
  QX_LidClamp  AT %QX100.4 : BOOL;
  QX_BaseClamp AT %QX100.5 : BOOL;
  QX_ZAxis     AT %QX100.6 : BOOL;
  QX_Grab      AT %QX100.7 : BOOL;
  QX_XAxis     AT %QX101.0 : BOOL;
  QX_Blade     AT %QX101.1 : BOOL;
  QX_GenBase   AT %QX101.2 : BOOL;
  QX_GenLid    AT %QX101.3 : BOOL;
END_VAR

(* ====== SEMANTICS, TIMERS, FB ====== *)
VAR
  (*INPUTS*)
  S_Start, S_Stop                      : BOOL;
  S_LidAtPlace, S_BaseAtPlace          : BOOL;
  S_LidClamped, S_BaseClamped          : BOOL;
  S_ZMoving, S_XMoving                 : BOOL;
  S_BladeLimit, S_PartLeaving          : BOOL;
  S_ItemDetected                       : BOOL;
  
  (*OUTPUTS*)
  Y_LidsConv, Y_BasesConv : BOOL;
  Y_LidClamp, Y_BaseClamp : BOOL;
  Y_ZAxis, Y_Grab, Y_XAxis: BOOL;
  Y_Blade                 : BOOL;
  Y_GenBase_i, Y_GenLid_i : BOOL;
  Y_AlarmLamp, Y_RunLamp  : BOOL;

  (*STATES *)
  STATE            : INT := 0;   (* 0=STOP, 1=RUN, 2=FAULT *)
  STATE_LIDS       : INT := 0;
  STATE_BASES      : INT := 0;
  STATE_CLAMP_LIDS : INT := 0;
  STATE_CLAMP_BASES: INT := 0;
  STATE_ARM        : INT := 0;

  (*START ANTI-BOUNCE*)
  DebStart : TON;  PT_DebStart : TIME := T#30ms;

  (* TRIGGERS *)
  FE_LaP : F_TRIG;
  FE_BaP : F_TRIG;
  FE_Zax : F_TRIG;
  FE_Xax : F_TRIG;
  RE_Grab : R_TRIG;
  FE_Grab : F_TRIG;
  RE_BladeHome : R_TRIG;
  FE_Leave : F_TRIG;

  (* AXIS WATCHDOGS *)
  Fault_TO_Z, Fault_TO_X : BOOL := FALSE;
  T_ZTimeout : TON;  PT_Z : TIME := T#10s;
  T_XTimeout : TON;  PT_X : TIME := T#10s;

  (* CONVEYOR JAMS *)
  Fault_JamLids, Fault_JamBases : BOOL := FALSE;
  T_LidsJam  : TON;  PT_LIDS  : TIME := T#10s;
  T_BasesJam : TON;  PT_BASES : TIME := T#10s;
END_VAR

(* MAP: RAW -> SEMANTIC *)
DebStart(IN := IX_Start, PT := PT_DebStart);
S_Start        := DebStart.Q;
S_Stop         := NOT IX_Stop;
S_LidAtPlace   := IX_LidAtPlace;
S_BaseAtPlace  := IX_BaseAtPlace;
S_LidClamped   := IX_LidClamped;
S_BaseClamped  := IX_BaseClamped;
S_ZMoving      := IX_ZMoving;
S_XMoving      := IX_XMoving;
S_BladeLimit   := IX_BladeLimit;
S_PartLeaving  := IX_PartLeaving;
S_ItemDetected := IX_ItemDetected;

FE_LaP(CLK := S_LidAtPlace);
FE_BaP(CLK := S_BaseAtPlace);
FE_Zax(CLK := S_ZMoving);
FE_Xax(CLK := S_XMoving);
RE_Grab(CLK := Y_Grab);
FE_Grab(CLK := Y_Grab);
RE_BladeHome(CLK := S_BladeLimit);
FE_Leave(CLK := S_PartLeaving);

(* MAIN LOGIC *)
CASE STATE OF
  0:  (* STOP *)
    Y_RunLamp := FALSE;   Y_AlarmLamp := FALSE;

    Y_LidsConv := FALSE;  Y_BasesConv := FALSE;
    Y_LidClamp := FALSE;  Y_BaseClamp := FALSE;
    Y_ZAxis := FALSE;     Y_Grab := FALSE;
    Y_XAxis := FALSE;     Y_Blade := FALSE;

    Fault_TO_Z := FALSE;  Fault_TO_X := FALSE;
    Fault_JamLids := FALSE; Fault_JamBases := FALSE;

    T_ZTimeout(IN := FALSE, PT := PT_Z);
    T_XTimeout(IN := FALSE, PT := PT_X);
    T_LidsJam (IN := FALSE, PT := PT_LIDS);
    T_BasesJam(IN := FALSE, PT := PT_BASES);

    IF S_Start & NOT S_Stop THEN
      STATE := 1;
      STATE_LIDS := 0; STATE_BASES := 0;
      STATE_CLAMP_LIDS := 0; STATE_CLAMP_BASES := 0;
      STATE_ARM := 0;
    END_IF;
    IF S_Stop THEN STATE:= 0; END_IF;


  1:  (* RUN *)
    IF S_Stop THEN STATE:= 0; END_IF;
    Y_RunLamp := TRUE;    Y_AlarmLamp := FALSE;

    (* LIDS CONVEYOR + JAM *)
    CASE STATE_LIDS OF
      0:
        Y_LidsConv := TRUE;
        T_LidsJam(IN := Y_LidsConv AND (NOT S_LidAtPlace), PT := PT_LIDS);
        IF FE_LaP.Q THEN
          STATE_LIDS := 1;
          T_LidsJam(IN := FALSE, PT := PT_LIDS);
        ELSIF T_LidsJam.Q THEN
          Fault_JamLids := TRUE;
          STATE := 2;   (*FAULT LIDS JAM *)
        END_IF;
      1:
        Y_LidsConv := FALSE;
        IF (Y_Grab AND FE_Zax.Q AND (NOT Y_ZAxis)) THEN
          STATE_LIDS := 0;
        END_IF;
    END_CASE;

    (* BASES CONVEYOR + JAM + BLADE *)
    CASE STATE_BASES OF
      0:
        Y_BasesConv := S_BladeLimit;
        T_BasesJam(IN := Y_BasesConv AND (NOT S_BaseAtPlace), PT := PT_BASES);
        IF FE_BaP.Q THEN
          STATE_BASES := 1;
          T_BasesJam(IN := FALSE, PT := PT_BASES);
        ELSIF T_BasesJam.Q THEN
          Fault_JamBases := TRUE;
          STATE := 2;   (*FAULT BASES JAM*)
        END_IF;
      1:
        Y_BasesConv := FALSE;
        IF (NOT Y_Grab) AND FE_Zax.Q AND Y_XAxis THEN
          STATE_BASES := 2;
          Y_Blade := TRUE;
        END_IF;
      2:
        IF RE_BladeHome.Q THEN
          STATE_BASES := 3;
          Y_BasesConv := TRUE;
        END_IF;
      3:
        IF FE_Leave.Q THEN
          Y_Blade := FALSE;
          STATE_BASES := 0;
          Y_BasesConv := FALSE;
        END_IF;
    END_CASE;

    (* CLAMPS *)
    CASE STATE_CLAMP_LIDS OF
      0:
        Y_LidClamp := FALSE;
        IF FE_LaP.Q THEN STATE_CLAMP_LIDS := 1; END_IF;
      1:
        Y_LidClamp := TRUE;
        IF RE_Grab.Q AND S_LidClamped THEN STATE_CLAMP_LIDS := 0; END_IF;
    END_CASE;

    CASE STATE_CLAMP_BASES OF
      0:
        Y_BaseClamp := FALSE;
        IF FE_BaP.Q THEN STATE_CLAMP_BASES := 1; END_IF;
      1:
        Y_BaseClamp := TRUE;
        IF FE_Grab.Q AND S_BaseClamped THEN STATE_CLAMP_BASES := 0; END_IF;
    END_CASE;

    (* WATCHDOGS AXIS *)
    T_ZTimeout(IN := Y_ZAxis, PT := PT_Z);
    IF T_ZTimeout.Q THEN Fault_TO_Z := TRUE; STATE := 2; END_IF;

    T_XTimeout(IN := Y_XAxis, PT := PT_X);
    IF T_XTimeout.Q THEN Fault_TO_X := TRUE; STATE := 2; END_IF;

    (*ROBOTIC ARM*)
    CASE STATE_ARM OF
      0:
        IF S_LidClamped THEN Y_ZAxis := TRUE; STATE_ARM := 1; END_IF;
      1:
        IF FE_Zax.Q AND S_ItemDetected THEN
          STATE_ARM := 2; Y_Grab := TRUE; Y_ZAxis := FALSE;
        END_IF;
      2:
        IF FE_Zax.Q THEN Y_XAxis := TRUE; STATE_ARM := 3; END_IF;
      3:
        IF FE_Xax.Q AND Y_Grab THEN STATE_ARM := 4; END_IF;
      4:
        IF S_BaseClamped THEN Y_ZAxis := TRUE; STATE_ARM := 5; END_IF;
      5:
        IF FE_Zax.Q THEN STATE_ARM := 6; Y_Grab := FALSE; Y_ZAxis := FALSE; END_IF;
      6:
        IF FE_Zax.Q THEN Y_XAxis := FALSE; STATE_ARM := 7; END_IF;
      7:
        IF FE_Xax.Q THEN STATE_ARM := 0; END_IF;
    END_CASE;

  2:  (* FAULT *)
    Y_RunLamp := FALSE;   Y_AlarmLamp := TRUE;
    Y_LidsConv := FALSE;  Y_BasesConv := FALSE;
    Y_LidClamp := FALSE;  Y_BaseClamp := FALSE;
    Y_XAxis := FALSE;     Y_Blade := FALSE;
    Y_ZAxis := FALSE;
    T_LidsJam (IN := FALSE, PT := PT_LIDS);
    T_BasesJam(IN := FALSE, PT := PT_BASES);
    T_ZTimeout(IN := FALSE, PT := PT_Z);
    T_XTimeout(IN := FALSE, PT := PT_X);

    IF S_Stop THEN STATE:= 0; END_IF;

  ELSE
    STATE := 0;
END_CASE;

(*MAP: SEMANTICS -> RAW *)
QX_RunLamp   := Y_RunLamp;
QX_AlarmLamp := Y_AlarmLamp;
QX_LidsConv  := Y_LidsConv;
QX_BasesConv := Y_BasesConv;
QX_LidClamp  := Y_LidClamp;
QX_BaseClamp := Y_BaseClamp;

QX_ZAxis     := Y_ZAxis;
QX_Grab      := Y_Grab;
QX_XAxis     := Y_XAxis;
QX_Blade     := Y_Blade;

QX_GenBase   := Y_GenBase_i;
QX_GenLid    := Y_GenLid_i;

END_PROGRAM


CONFIGURATION Config0
  RESOURCE Res0 ON PLC
    TASK task0(INTERVAL := T#20ms, PRIORITY := 0);
    PROGRAM P0 WITH task0 : Assembly;
  END_RESOURCE
END_CONFIGURATION
