import React, { useEffect, useState } from 'react';
import useWebSocket, { ReadyState } from 'react-use-websocket';

import Board from './Board';
import { Box, Button, Stack, Typography } from '@mui/joy';
import { getWebsocketUrl } from './config';
import { ISnack } from './App';

export type Square = string | null;

export interface IBoard {
  pieces: (Square | null)[][];
}

function Game({ setErrMessage, gameToken, playerToken }: { setErrMessage: (err: ISnack | null) => void, gameToken: string, playerToken: string }) {
  const { sendMessage, lastMessage, readyState, } = useWebSocket(getWebsocketUrl() + gameToken + '/' + playerToken);

  const [board, setBoard] = useState<IBoard | null>(null);
  const [activePlayer, setActivePlayer] = useState<string | null>(null);

  useEffect(() => {
    if (readyState === ReadyState.OPEN) {
      sendMessage('get_board');
      sendMessage('get_player');
    }
    else if (readyState === ReadyState.CLOSED) {
      setErrMessage({
        message: 'Connection closed. Please refresh the page.',
        severity: 'danger',
      });
    }
  }, [readyState, sendMessage, setErrMessage]);

  useEffect(() => {
    if (lastMessage !== null) {
      if (lastMessage.data.startsWith('board=')) {
        setBoard(parseBoard(lastMessage.data.slice(6)));
      }
      else if (lastMessage.data.startsWith('player=')) {
        setActivePlayer(lastMessage.data.slice(7));
      }
      else if (lastMessage.data.startsWith('error=')) {
        setErrMessage({
          message: lastMessage.data.slice(6),
          severity: 'danger',
        });
      }
      else if (lastMessage.data.startsWith('winner=')) {
        setErrMessage({
          message: `Winner: ${lastMessage.data.slice(7)}`,
          severity: 'success',
        });
      }
    }
  }, [lastMessage, setErrMessage]);


  const [selectedPiece, setSelectedPiece] = useState<string | null>(null);
  const clickHandler = (coord: string) => {
    if (selectedPiece === null) {
      setSelectedPiece(coord);
    }
    else {
      sendMessage(`move=move=${activePlayer},${selectedPiece},${coord}`.toLowerCase());
      setSelectedPiece(null);
    }
  }

  return (
    <>
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
            {selectedPiece !== null && <Button onClick={() => setSelectedPiece(null)}>Cancel move from {selectedPiece.toUpperCase()}</Button>}
          </Stack>
        </Box>
        {readyState === 0 ? <p>Connecting...</p> : board === null ? <p>Loading board...</p> : <Board board={board} clickHandler={clickHandler} />}
      </Box>
    </>
  );
}

export default Game;

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
