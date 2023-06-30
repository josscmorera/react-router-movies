import './App.css';
import { useState } from 'react';
import { Outlet } from 'react-router-dom';
import NavBar from './Components/NavBar';

function App() {
  const [movies, setMovies] = useState([]);

  return (
    <div className="App">
      <NavBar />
      <Outlet context={{movies, setMovies}} />
    </div>
  );
}

export default App;
