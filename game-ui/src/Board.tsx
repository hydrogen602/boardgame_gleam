import { Box } from "@mui/joy";
import { IBoard } from "./App";




function Board({ board }: { board: IBoard }) {
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
                  specialColor;

            const isSpecial = squareColor === specialColor;

            return (<Box key={`${rowIndex}-${colIndex}`} sx={{
              backgroundColor: isSpecial ? specialColor : null,
              width: '1em',
              height: '1em',
              border: isSpecial ? '' : '1px solid black',
              gridColumn: `${colIndex + 1} / span 1`,
              gridRow: `${rowIndex + 1} / span 1`,
              display: 'flex',
              justifyContent: 'center',
              alignItems: 'center',
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