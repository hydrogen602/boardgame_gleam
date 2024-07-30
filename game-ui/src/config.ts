
export function getWebsocketUrl() {
  if (process.env.NODE_ENV === 'development') {
    return 'ws://localhost:3000/ws/';
  }
  if (process.env.NODE_ENV === 'production') {
    return 'wss://lightsail.hydrogen602.com/ws/';
  }
  throw new Error('Unknown environment');
}
