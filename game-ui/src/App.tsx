import { Box, Button, Card, Input, Snackbar, Typography } from "@mui/joy";
import Game from "./Game";
import { useLocalStorage } from "./util";
import React, { useEffect, useState } from "react";
import ErrorIcon from '@mui/icons-material/Error';
import { getApiUrl } from "./config";



export interface ISnack {
  message: string;
  severity: 'success' | 'danger';
}

function isValidToken(token: string): boolean {
  // only hex characters
  return /^[0-9a-fA-F]+$/.test(token);
}

function App() {
  const [gameToken, setGameToken] = useLocalStorage<string | null>(null, "gameToken");
  const [playerToken, setPlayerToken] = useLocalStorage<string | null>(null, "playerToken");

  useEffect(() => {
    console.log('gameToken:', gameToken, '\n', 'playerToken:', playerToken);
  }, [gameToken, playerToken]);

  const [errMessage, setErrMessage] = useState<ISnack | null>(null);

  const [tmpGameToken, setTmpGameToken] = useState<string>('');

  const joinHandler = async (color: 'white' | 'black') => {
    try {
      const resp = await fetch(getApiUrl() + `join_game/${color}/${gameToken}`);
      const data = await resp.text();
      if (resp.status !== 200) {
        throw data;
      }
      if (!isValidToken(data)) {
        throw new Error('Invalid token: ' + data);
      }
      setPlayerToken(data);
    }
    catch (e) {
      setErrMessage({
        message: 'Failed to join game: ' + e,
        severity: 'danger',
      });
    }
  };

  let inner: React.ReactElement | null = null;
  if (gameToken === null) {
    inner = (<>
      <Card sx={{
        padding: '1em',
        marginBottom: '1em',
      }}>
        <Typography level='h1'>Start New Game</Typography>
        <Button onClick={async () => {
          try {
            const resp = await fetch(getApiUrl() + 'get_code');
            const data = await resp.text();
            if (resp.status !== 200) {
              throw data;
            }
            if (!isValidToken(data)) {
              throw new Error('Invalid token: ' + data);
            }
            setGameToken(data);
          }
          catch (e) {
            setErrMessage({
              message: 'Failed to create game: ' + e,
              severity: 'danger',
            });
          }
        }}>Create Game</Button>
      </Card >
      <Card sx={{
        padding: '1em',
        marginBottom: '1em',
      }}>
        <Typography level='h1'>Join Existing Game</Typography>
        <Input placeholder='Game Code' onChange={(e) => setTmpGameToken(e.target.value)} value={tmpGameToken} />
        <Button onClick={() => setGameToken(tmpGameToken)
        }>Apply Code</Button>
      </Card>
    </>
    );
  }
  else if (playerToken === null) {
    inner = (
      <Card sx={{
        gap: '1em',
        padding: '2em',
      }}>
        <Typography level='h1'>Game Code: {gameToken}</Typography>
        <Button onClick={() => joinHandler('white')
        } variant="solid">Join Game as White</Button>
        <Button onClick={() => joinHandler('black')
        } variant="solid">Join Game as Black</Button>

        <Button onClick={() => {
          setGameToken(null);
          setPlayerToken(null);
        }} variant="soft" color="danger">
          Exit Game
        </Button>
      </Card >
    );
  }
  else {
    inner = <Game setErrMessage={setErrMessage} gameToken={gameToken} playerToken={playerToken} />;
  }

  return (
    <>
      <Snackbar
        onClose={(event, reason) => {
          if (reason === 'clickaway' || reason === 'escapeKeyDown') {
            return;
          }
          setErrMessage(null);
        }}
        onClick={() => setErrMessage(null)}
        open={errMessage !== null}
        color={errMessage?.severity}
        variant='soft'
        autoHideDuration={10000}
        startDecorator={<ErrorIcon />}
        anchorOrigin={{ vertical: 'top', horizontal: 'center' }}

      >{errMessage?.message}</Snackbar>
      <Button onClick={() => {
        setGameToken(null);
        setPlayerToken(null);
      }} sx={{
        position: 'absolute',
        top: 0,
        left: 0,
        zIndex: 1000,
      }}>
        Reset
      </Button>
      <Box sx={{
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
        {inner}
      </Box>
    </>
  );
}

export default App;