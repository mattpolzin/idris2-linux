module System.Posix.Pthreads

import public Data.C.Ptr
import public System.Posix.Errno
import public System.Posix.Pthreads.Types
import System.Posix.Time

%default total

--------------------------------------------------------------------------------
-- FFI
--------------------------------------------------------------------------------

%foreign "C:pthread_equal, posix-idris"
prim__pthread_equal : AnyPtr -> AnyPtr -> Bits8

%foreign "C:pthread_self, posix-idris"
prim__pthread_self : PrimIO AnyPtr

%foreign "C:li_pthread_join, posix-idris"
prim__pthread_join : AnyPtr -> PrimIO Bits32

%foreign "C:li_pthread_mutex_init, posix-idris"
prim__pthread_mutex_init : AnyPtr -> Bits8 -> PrimIO Bits32

%foreign "C:li_pthread_mutex_destroy, posix-idris"
prim__pthread_mutex_destroy : AnyPtr -> PrimIO ()

%foreign "C:pthread_mutex_lock, posix-idris"
prim__pthread_mutex_lock : AnyPtr -> PrimIO Bits32

%foreign "C:pthread_mutex_trylock, posix-idris"
prim__pthread_mutex_trylock : AnyPtr -> PrimIO Bits32

%foreign "C:pthread_mutex_timedlock, posix-idris"
prim__pthread_mutex_timedlock : AnyPtr -> AnyPtr -> PrimIO Bits32

%foreign "C:pthread_mutex_unlock, posix-idris"
prim__pthread_mutex_unlock : AnyPtr -> PrimIO Bits32

%foreign "C:li_pthread_cond_init, posix-idris"
prim__pthread_cond_init : AnyPtr -> PrimIO Bits32

%foreign "C:li_pthread_cond_destroy, posix-idris"
prim__pthread_cond_destroy : AnyPtr -> PrimIO ()

%foreign "C:pthread_cond_signal, posix-idris"
prim__pthread_cond_signal : AnyPtr -> PrimIO Bits32

%foreign "C:pthread_cond_broadcast, posix-idris"
prim__pthread_cond_broadcast : AnyPtr -> PrimIO Bits32

%foreign "C:pthread_cond_wait, posix-idris"
prim__pthread_cond_wait : AnyPtr -> AnyPtr -> PrimIO Bits32

%foreign "C:pthread_cond_timedwait, posix-idris"
prim__pthread_cond_timedwait : AnyPtr -> AnyPtr -> AnyPtr -> PrimIO Bits32

--------------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------------

||| Wrapper around an identifier for a POSIX thread.
export
record PthreadT where
  constructor P
  ptr : AnyPtr

||| Returns the thread ID of the current thread.
export %inline
pthreadSelf : HasIO io => io PthreadT
pthreadSelf = primIO $ primMap P $ prim__pthread_self

||| Blocks the current thread and waits for the given thread to terminate.
export %inline
pthreadJoin : PthreadT -> IO (Either Errno ())
pthreadJoin p = posToUnit $ prim__pthread_join p.ptr

export %inline
Eq PthreadT where
  x == y = toBool (prim__pthread_equal x.ptr y.ptr)

||| Warning: This `Show` implementation for thread IDs is for debugging only!
||| According to SUSv3, a thread ID need not be a scalar, so it should be
||| treated as an opaque type.
|||
||| On many implementations (including on Linux), they are just integers, so
||| this can be useful for debugging.
export %inline
Show PthreadT where
  show (P p) = show (believe_me {b = Bits64} p)

--------------------------------------------------------------------------------
-- MutexT
--------------------------------------------------------------------------------

||| Wrapper around a `pthread_mutex_t` pointer.
|||
||| Noted: While this provides additional flexibility over the type of mutex
||| we use (see `mkmutex`) and how we acquire a lock on a mutex, it is less
||| convenient to use than the garbage-collected version from
||| `System.Concurrency`.
export
record MutexT where
  constructor M
  ptr : AnyPtr

%inline
Struct MutexT where
  unwrap = ptr
  wrap   = M

%inline
SizeOf MutexT where sizeof_ = mutex_t_size

||| Allocates and initializes a new mutex of the given type.
|||
||| This must be freed with `destroyMutex`.
export
mkmutex : MutexType -> IO (Either Errno MutexT)
mkmutex t = do
  m <- allocStruct MutexT
  e <- posToUnit $ prim__pthread_mutex_init m.ptr (mutexCode t)
  case e of
    Left x  => freeStruct m $> Left x
    Right () => pure (Right m)

||| Destroys a mutex and frees the memory allocated for it.
export %inline
destroyMutex : HasIO io => MutexT -> io ()
destroyMutex m = primIO $ prim__pthread_mutex_destroy m.ptr

||| Tries to lock the given mutex, blocking the calling thread
||| in case it is already locked.
export %inline
lockMutex : MutexT -> IO (Either Errno ())
lockMutex p = posToUnit $ prim__pthread_mutex_lock p.ptr

export %inline
timedlockMutex : MutexT -> Timespec -> IO (Either Errno ())
timedlockMutex p t = posToUnit $ prim__pthread_mutex_timedlock p.ptr (unwrap t)

||| Like `lockMutex` but fails with `EBUSY` in case the mutex is
||| already locked.
export %inline
trylockMutex : MutexT -> IO (Either Errno ())
trylockMutex p = posToUnit $ prim__pthread_mutex_trylock p.ptr

||| Unlocks the given mutex.
|||
||| This is an error if the calling thread is not the one holding
||| the mutex's lock.
export %inline
unlockMutex : MutexT -> IO (Either Errno ())
unlockMutex p = posToUnit $ prim__pthread_mutex_unlock p.ptr

--------------------------------------------------------------------------------
-- CondT
--------------------------------------------------------------------------------

||| Wrapper around a `pthread_cond_t` pointer.
|||
||| Noted: While this provides additional flexibility over the type of condition
||| we use (see `mkcond`) convenient to use than the garbage-collected version from
||| `System.Concurrency`.
export
record CondT where
  constructor C
  ptr : AnyPtr

%inline
Struct CondT where
  unwrap = ptr
  wrap   = C

%inline
SizeOf CondT where sizeof_ = cond_t_size

||| Allocates and initializes a new condition variable.
|||
||| This must be freed with `destroyCond`.
export
mkcond : IO (Either Errno CondT)
mkcond = do
  m <- allocStruct CondT
  e <- posToUnit $ prim__pthread_cond_init m.ptr
  case e of
    Left x   => freeStruct m $> Left x
    Right () => pure (Right m)

||| Destroys a condition variable and frees the memory allocated for it.
export %inline
destroyCond : HasIO io => CondT -> io ()
destroyCond m = primIO $ prim__pthread_cond_destroy m.ptr

||| Signals the given `pthread_cond_t`.
|||
||| If several threads are waiting on the condition, it is unspecified
||| which of them will be signalled. We are only guaranteed that at least
||| of them will be woken up.
export %inline
condSignal : CondT -> IO (Either Errno ())
condSignal p = posToUnit $ prim__pthread_cond_signal p.ptr

||| Broadcasts the given `pthread_cond_t`.
|||
||| This will wake up all threads waiting on the given condition.
export %inline
condBroadcast : CondT -> IO (Either Errno ())
condBroadcast p = posToUnit $ prim__pthread_cond_broadcast p.ptr

||| Blocks the given thread and waits for the given condition to
||| be signalled.
|||
||| Note: The mutex must have been locked by the calling thread. The
||| lock is automatically released upon calling `condWait`, and when
||| the thread is woken up, the mutex will automatically be locked again.
export %inline
condWait : CondT -> MutexT -> IO (Either Errno ())
condWait p m = posToUnit $ prim__pthread_cond_wait p.ptr m.ptr

||| Like `condWait` but will return with `ETIMEDOUT` after the given
||| time interval expires.
export %inline
condTimedwait : CondT -> MutexT -> Timespec -> IO (Either Errno ())
condTimedwait p m t =
  posToUnit $ prim__pthread_cond_timedwait p.ptr m.ptr (unwrap t)