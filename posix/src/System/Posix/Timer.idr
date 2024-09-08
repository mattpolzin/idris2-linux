module System.Posix.Timer

import Data.C.Ptr

import public Data.C.Integer
import public System.Posix.Errno
import public System.Posix.Timer.Types
import public System.Posix.Time

%default total

--------------------------------------------------------------------------------
-- Timeval
--------------------------------------------------------------------------------

%foreign "C:get_timeval_tv_sec, posix-idris"
get_timeval_tv_sec: AnyPtr -> PrimIO TimeT

%foreign "C:get_timeval_tv_usec, posix-idris"
get_timeval_tv_usec: AnyPtr -> PrimIO SusecondsT

%foreign "C:set_timeval_tv_sec, posix-idris"
set_timeval_tv_sec: AnyPtr -> TimeT -> PrimIO ()

%foreign "C:set_timeval_tv_usec, posix-idris"
set_timeval_tv_usec: AnyPtr -> SusecondsT -> PrimIO ()

%foreign "C:li_timeval, posix-idris"
prim__timeval : TimeT -> SusecondsT -> PrimIO AnyPtr

export
record Timeval where
  constructor TV
  ptr : AnyPtr

export %inline
Struct Timeval where
  wrap   = TV
  unwrap = ptr

export %inline
SizeOf Timeval where
  sizeof_ = timeval_size

export %inline
sec : HasIO io => Timeval -> io TimeT
sec s = primIO $ get_timeval_tv_sec s.ptr

export %inline
usec : HasIO io => Timeval -> io SusecondsT
usec s = primIO $ get_timeval_tv_usec s.ptr

export %inline
setsec : HasIO io => Timeval -> TimeT -> io ()
setsec s v = primIO $ set_timeval_tv_sec s.ptr v

export %inline
setusec : HasIO io => Timeval -> SusecondsT -> io ()
setusec s v = primIO $ set_timeval_tv_usec s.ptr v

export %inline
timeval : HasIO io => TimeT -> SusecondsT -> io Timeval
timeval s u = primIO $ primMap TV $ prim__timeval s u

--------------------------------------------------------------------------------
-- Itimerval
--------------------------------------------------------------------------------

%foreign "C:get_itimerval_it_interval, posix-idris"
get_itimerval_it_interval: AnyPtr -> PrimIO AnyPtr

%foreign "C:get_itimerval_it_value, posix-idris"
get_itimerval_it_value: AnyPtr -> PrimIO AnyPtr

%foreign "C:set_itimerval_it_interval, posix-idris"
set_itimerval_it_interval: AnyPtr -> AnyPtr -> PrimIO ()

%foreign "C:set_itimerval_it_value, posix-idris"
set_itimerval_it_value: AnyPtr -> AnyPtr -> PrimIO ()

%foreign "C:li_itimerval, posix-idris"
prim__itimerval : TimeT -> SusecondsT -> TimeT -> SusecondsT -> PrimIO AnyPtr

export
record Itimerval where
  constructor ITV
  ptr : AnyPtr

export %inline
Struct Itimerval where
  wrap   = ITV
  unwrap = ptr

export %inline
SizeOf Itimerval where
  sizeof_ = itimerval_size

export %inline
interval : HasIO io => Itimerval -> io Timeval
interval s = primIO $ primMap TV $ get_itimerval_it_interval s.ptr

export %inline
value : HasIO io => Itimerval -> io Timeval
value s = primIO $ primMap TV $ get_itimerval_it_value s.ptr

export %inline
setinterval : HasIO io => Itimerval -> Timeval -> io ()
setinterval s v = primIO $ set_itimerval_it_interval s.ptr v.ptr

export %inline
setvalue : HasIO io => Itimerval -> Timeval -> io ()
setvalue s v = primIO $ set_itimerval_it_value s.ptr v.ptr

||| Creates and sets the fields of a `Itimerval` pointer.
|||
||| The allocated memory must be freed via `freeItimerval`.
export %inline
itimerval :
     {auto has     : HasIO io}
  -> (secInterval  : TimeT)
  -> (usecInterval : SusecondsT)
  -> (secValue     : TimeT)
  -> (usecValue    : SusecondsT)
  -> io Itimerval
itimerval si ui sv uv = do
  primIO $ primMap ITV $ prim__itimerval si ui sv uv

--------------------------------------------------------------------------------
-- FFI
--------------------------------------------------------------------------------

%foreign "C:clock, posix-idris"
prim__clock : PrimIO ClockT

%foreign "C:alarm, posix-idris"
prim__alarm : UInt -> PrimIO UInt

%foreign "C:li_setitimer, posix-idris"
prim__setitimer : Bits8 -> AnyPtr -> AnyPtr -> PrimIO CInt

%foreign "C:li_setitimer1, posix-idris"
prim__setitimer1 : Bits8 -> AnyPtr -> PrimIO CInt

%foreign "C:li_getitimer, posix-idris"
prim__getitimer : Bits8 -> AnyPtr -> PrimIO CInt

%foreign "C:li_clock_gettime, posix-idris"
prim__clock_gettime : Bits8 -> AnyPtr -> PrimIO CInt

%foreign "C:li_clock_getres, posix-idris"
prim__clock_getres : Bits8 -> AnyPtr -> PrimIO CInt

--------------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------------

||| Returns an approximation of processor time used by the program.
|||
||| Type `ClockT` measures time with a granularity of
||| `CLOCKS_PER_SEC`.
export %inline
clock : HasIO io => io ClockT
clock = primIO prim__clock

||| This sets `new` as the new timer and places the current timer for
||| `Which` in `old`.
|||
||| Depending on `Which`, the timer will use a different clock and
||| will (possibly repeatedly) raise a different kind signal:
|||
||| * ITIMER_REAL: Counts down in real (i.e. wall clock) time
|||   and raises SIGALRM
||| * ITIMER_VIRTUAL: Counts down in process virtual time
|||   (i.e. user-mode CPU time) and raises SIGVTALRM
||| * ITIMER_PROF: Counts down in process time
|||   (i.e. the sum of kernel-mode and user-mode CPU time) and raises SIGPROF
export %inline
setitimer : Which -> (new,old : Itimerval) -> IO (Either Errno ())
setitimer w (ITV n) (ITV o) = toUnit $ prim__setitimer (whichCode w) n o

||| Like `setitimer` but does not store the old timer in a pointer.
export %inline
setitimer' : Which -> (new : Itimerval) -> IO (Either Errno ())
setitimer' w (ITV n) = toUnit $ prim__setitimer1 (whichCode w) n

||| Writes the currently set timer for `Which` into `old.
export %inline
getitimer : Which -> (old : Itimerval) -> IO (Either Errno ())
getitimer w (ITV o) = toUnit $ prim__getitimer (whichCode w) o

||| A very basic version of `setitimer` that raises `SIGALRM`
||| after the given number of seconds.
|||
||| The returned value is the remaining number of seconds on any
||| previously set timer. The timer can be disabled by setting
||| this to zero.
export %inline
alarm : HasIO io => UInt -> io UInt
alarm s = primIO $ prim__alarm s

||| Writes the current time for the given clock into the
||| `Timespec` pointer.
export %inline
clockGetTime : ClockId -> Timespec -> IO (Either Errno ())
clockGetTime c t = toUnit $ prim__clock_gettime (clockCode c) (unwrap t)

||| Writes the resolution for the given clock into the
||| `Timespec` pointer.
export %inline
clockGetRes : ClockId -> Timespec -> IO (Either Errno ())
clockGetRes c t = toUnit $ prim__clock_getres (clockCode c) (unwrap t)