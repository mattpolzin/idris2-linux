module Example.Ch44.ChunkPipe

import Data.Vect
import Example.Util.File
import Example.Util.Opts
import Example.Util.Pretty
import System.Linux.Pipe
import System.Posix.Process

%default total

usage : String
usage =
  """
  Usage: linux-examples chunk_pipe BYTES RBYTES WBYTES [1|2|3]

  Forks a child and writes BYTES bytes of data to a pipe in
  chunks of WBYTES. The parent reads these bytes in chunks of
  RBYTES.

  This demonstrates the following: Writing to a pipe will block until
  all bytes have been written at least into the kernel buffer. Reads will
  read as many bytes as are currently available in the kernel buffer.
  For instance, on my system, reads will never consume
  more than 0x10000 bytes of data even if RBYTES is larger.

  The optional flag at the end can be used to set the `O_DIRECT` (1),
  `O_NONBLOCK` (2), or both (3) flags.
  """

parameters {auto he : Has Errno es}
           {auto ha : Has ArgErr es}

  covering
  prnt : Bits32 -> Vect 2 Fd -> Prog es ()
  prnt sz [i,o] = do
    injectIO (close o)
    buf <- primIO (prim__newBuf sz)
    strm buf
    injectIO (close i)

    where
      covering
      strm : Buffer -> Prog es ()
      strm buf =
        liftIO (readRaw i buf sz) >>= \case
          Right 0     => stdoutLn "End of input."
          Right n     => stdoutLn "\{show n} bytes read" >> strm buf
          Left EAGAIN => stdoutLn "read: currently no data" >> strm buf
          Left x      => fail x

  covering
  chld : Bits32 -> Bits32 -> Vect 2 Fd -> Prog es ()
  chld tot sz [i,o] = do
    injectIO (close i)
    buf <- primIO (prim__newBuf sz)
    strm buf tot
    injectIO (close o)

    where
      covering
      strm : Buffer -> (rem : Bits32) -> Prog es ()
      strm buf 0   = pure ()
      strm buf rem =
        liftIO (writeRaw o buf 0 (min rem sz)) >>= \case
          Right w => stdoutLn "\{show w} bytes written" >> strm buf (rem - w)
          Left EAGAIN => stdoutLn "write: currently no space" >> strm buf rem
          Left x      => fail x

  covering
  run : (ts,rs,ws : String) -> Flags -> Prog es ()
  run ts rs ws fs = do
    tot <- readOptIO OBits32 ts
    rbs <- readOptIO OBits32 rs
    wbs <- readOptIO OBits32 ws
    fds <- use1 (malloc _ _) $ \r => injectIO (pipe2 r fs) >> readVectIO r
    0 <- injectIO fork | p => prnt rbs fds
    chld tot wbs fds

  export covering
  chunkPipe : List String -> Prog es ()
  chunkPipe ["--help"]     = stdoutLn "\{usage}"
  chunkPipe [ts,rs,ws]     = run ts rs ws 0
  chunkPipe [ts,rs,ws,"1"] = run ts rs ws O_DIRECT
  chunkPipe [ts,rs,ws,"2"] = run ts rs ws O_NONBLOCK
  chunkPipe [ts,rs,ws,"3"] = run ts rs ws (O_DIRECT <+> O_NONBLOCK)
  chunkPipe args           = fail (WrongArgs usage)
