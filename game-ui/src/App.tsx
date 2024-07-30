import React, { useEffect, useState } from 'react';
import useWebSocket, { ReadyState } from 'react-use-websocket';
import ErrorIcon from '@mui/icons-material/Error';

import Board from './Board';
import { Box, Button, Snackbar, Stack, Typography } from '@mui/joy';
import { getWebsocketUrl } from './config';

export type Square = string | null;

export interface IBoard {
  pieces: (Square | null)[][];
}

function App() {
  const { sendMessage, lastMessage, readyState } = useWebSocket(getWebsocketUrl());

  const [board, setBoard] = useState<IBoard | null>(null);
  const [activePlayer, setActivePlayer] = useState<string | null>(null);

  useEffect(() => {
    if (readyState === ReadyState.OPEN) {
      sendMessage('get_board');
      sendMessage('get_player');
    }
  }, [readyState, sendMessage]);

  useEffect(() => {
    if (lastMessage !== null) {
      console.log(lastMessage);
      if (lastMessage.data.startsWith('board=')) {
        setBoard(parseBoard(lastMessage.data.slice(6)));
      }
      else if (lastMessage.data.startsWith('player=')) {
        setActivePlayer(lastMessage.data.slice(7));
      }
      else if (lastMessage.data.startsWith('error=')) {
        setErrMessage(lastMessage.data.slice(6));
      }
    }
  }, [lastMessage]);

  const [errMessage, setErrMessage] = useState<string | null>(null);

  return (
    <div className="App">
      <Snackbar
        onClose={(event, reason) => {
          if (reason === 'clickaway' || reason === 'escapeKeyDown') {
            return;
          }
          setErrMessage(null);
        }}
        onClick={() => setErrMessage(null)}
        open={errMessage !== null}
        color='danger'
        autoHideDuration={10000}
        startDecorator={<ErrorIcon />}
        anchorOrigin={{ vertical: 'top', horizontal: 'center' }}

      >{errMessage}</Snackbar>
      <Box sx={{
        padding: '0.5em',
        height: '100vh',
        width: '100vw',
        position: 'absolute',
        top: 0,
        left: 0,
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'center',
        alignItems: 'center',
        backgroundColor: 'lightgray',
      }}>
        <Box sx={{
          marginBottom: '1em',
        }}>
          <Stack direction="row" spacing={2}>
            <Typography level="h3">
              {activePlayer === null ? 'Loading player...' : 'Turn: ' + activePlayer}
            </Typography>
            <Button onClick={() => {
              sendMessage(`move=place=${activePlayer}`.toLowerCase());
            }}>Place pieces</Button>
          </Stack>
        </Box>
        {readyState === 0 ? <p>Connecting...</p> : board === null ? <p>Loading board...</p> : <Board board={board} />}
      </Box>
    </div>
  );
}

export default App;

function parseBoard(message: string): IBoard {
  const convertOne = (rawPiece: string): Square => {
    let piece = rawPiece.trim();
    if (piece === 'null' || piece === '' || piece === '_') {
      return null;
    }
    return piece;
  }

  const pieces = message.split('\n').map(row => row.split(' ').map(convertOne));
  return { pieces };
}
