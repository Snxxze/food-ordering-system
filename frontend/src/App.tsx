import { useEffect, useState } from 'react'
import './App.css'

interface MenuItem {
  id: number;
  name: string;
  price: number;
}

function App() {
  const [menu, setMenu] = useState<MenuItem[]>([])

  useEffect(() => {
    fetch('http://localhost:8080/api/menu')
      .then(res => res.json())
      .then((data: MenuItem[]) => setMenu(data))
      .catch(err => console.error('Error:', err))
  }, [])

  return (
    <div className="App">
      <header style={{ background: '#333', color: '#fff', padding: '1rem' }}>
        <h1>Food Ordering App</h1>
      </header>
      <main style={{ padding: '20px' }}>
        <h2>Menu</h2>
        <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
          {menu.map(item => (
            <div key={item.id} style={{ border: '1px solid #ccc', padding: '10px', borderRadius: '5px' }}>
              <h3>{item.name}</h3>
              <p>ราคา: {item.price} บาท</p>
              <button onClick={() => alert('สั่งสำเร็จ!')}>Order Now</button>
            </div>
          ))}
        </div>
      </main>
    </div>
  )
}

export default App
