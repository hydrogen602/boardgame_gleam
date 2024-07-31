import { Box } from "@mui/joy";
import { IBoard } from "./Game";




function Board({ board, clickHandler }: { board: IBoard, clickHandler: (coord: string) => void }) {
  const rowCount = board.pieces.length;
  const colCount = rowCount === 0 ? 0 : board.pieces[0].length;


  return (
    <Box sx={{
      fontSize: `calc(min(80vh, 90vw) / ${Math.max(rowCount, colCount)})`,
      border: '5px solid black',
    }}>
      <Box sx={{
        display: 'grid',
        gridTemplateColumns: `repeat(${colCount}, 1em)`,
        gridTemplateRows: `repeat(${rowCount}, 1em)`,
        gap: 0,
        // width: '100%',
        // height: '100%',
        justifyItems: 'center',
        alignItems: 'center',
        justifyContent: 'center',
        alignContent: 'center',
      }}>
        {board.pieces.map((row, rowIndex) => (
          row.map((piece, colIndex) => {
            const specialColor = 'whitesmoke';

            const squareColor = piece === '●' ? 'white' :
              piece === '○' ? 'black' :
                piece === '·' ? 'transparent' :
                  piece === '+' ? 'rgb(255, 194, 0, 0.5)' :
                    specialColor;

            const isSpecial = squareColor === specialColor;

            return (<Box key={`${rowIndex}-${colIndex}`}
              onClick={isSpecial ? undefined : () =>
                clickHandler(IdxToCoord(rowIndex, colIndex))
              }

              sx={{
                backgroundColor: isSpecial ? specialColor : null,
                width: '1em',
                height: '1em',
                border: isSpecial ? '' : '1px solid black',
                gridColumn: `${colIndex + 1} / span 1`,
                gridRow: `${rowIndex + 1} / span 1`,
                display: 'flex',
                justifyContent: 'center',
                alignItems: 'center',
                '&:hover': {
                  boxShadow: isSpecial ? null : '0 0 0 10px yellow',
                },
                '&:active': {
                  boxShadow: isSpecial ? null : '0 0 0 10px red',
                },
              }}>
              {isSpecial ? <p style={{
                display: 'inline-block',
                margin: 0,
                padding: 0,
                lineHeight: 'calc(1em - 10%)',
                fontSize: 'calc(1em - 10%)',
                width: 'calc(1em - 10%)',
                height: 'calc(1em - 10%)',
                textAlign: 'center',
                backgroundColor: squareColor,
              }}>{piece}</p> :
                <p style={{
                  display: 'inline-block',
                  margin: 0,
                  padding: 0,
                  lineHeight: 'calc(1em - 10%)',
                  fontSize: 'calc(1em - 10%)',
                  width: 'calc(1em - 10%)',
                  height: 'calc(1em - 10%)',
                  textAlign: 'center',
                  borderRadius: '50%',
                  backgroundColor: squareColor,
                }}>&nbsp;</p> /* &nbsp; */}

            </Box>);
          })
        ))}
      </Box>
    </Box>);
}

export default Board;

function IdxToCoord(rowIdx: number, colIdx: number): string {
  let row: string | null = null;
  let col: string | null = null;

  if (colIdx === 1) {
    col = 'A';
  }
  else if (colIdx === 2) {
    col = 'B';
  }
  else if (colIdx === 3) {
    col = 'C';
  }
  else if (colIdx === 4) {
    col = 'D';
  }
  else if (colIdx === 5) {
    col = 'E';
  }
  else if (colIdx === 6) {
    col = 'F';
  }
  else if (colIdx === 7) {
    col = 'G';
  }
  else if (colIdx === 8) {
    col = 'H';
  }

  if (rowIdx >= 1 && rowIdx <= 8) {
    row = (8 - rowIdx + 1).toString();
  }

  if (row === null || col === null) {
    throw new Error(`Invalid rowIdx or colIdx: ${rowIdx}, ${colIdx}`);
  }
  return `${col}${row}`.toLowerCase();
}