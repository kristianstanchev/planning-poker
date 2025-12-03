import { useState } from 'react';

const fibonacciCards = [0, 1, 2, 3, 5, 8, 13, 21, 34];
const tshirtSizes = ['XS', 'S', 'M', 'L', 'XL'];

function App() {
  const [name, setName] = useState('');
  const [room, setRoom] = useState('');
  const [selectedCard, setSelectedCard] = useState(null);

  if (!name || !room) {
    return (
      <div className="flex flex-col items-center justify-center h-screen gap-4">
        <input
          className="p-2 rounded text-black"
          placeholder="Your name"
          value={name}
          onChange={e => setName(e.target.value)}
        />
        <input
          className="p-2 rounded text-black"
          placeholder="Room"
          value={room}
          onChange={e => setRoom(e.target.value)}
        />
        <button
          className="bg-blue-600 px-4 py-2 rounded hover:bg-blue-700"
          onClick={() => {}}
        >
          Join
        </button>
      </div>
    )
  }

  return (
    <div className="flex flex-col items-center justify-center h-screen gap-4">
      <h1 className="text-2xl">Planning Poker</h1>
      <div className="grid grid-cols-5 gap-4">
        {fibonacciCards.map(card => (
          <button
            key={card}
            className={`w-20 h-28 bg-gray-700 rounded text-white text-xl flex items-center justify-center hover:bg-gray-600 ${selectedCard === card ? 'ring-4 ring-blue-500' : ''}`}
            onClick={() => setSelectedCard(card)}
          >
            {card}
          </button>
        ))}
        {tshirtSizes.map(size => (
          <button
            key={size}
            className={`w-20 h-28 bg-gray-700 rounded text-white text-xl flex items-center justify-center hover:bg-gray-600 ${selectedCard === size ? 'ring-4 ring-blue-500' : ''}`}
            onClick={() => setSelectedCard(size)}
          >
            {size}
          </button>
        ))}
      </div>
      {selectedCard && <div className="mt-4 text-xl">You selected: {selectedCard}</div>}
    </div>
  )
}

export default App;
