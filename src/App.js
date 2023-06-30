import NavBar from './Components/NavBar';
import './App.css';
import { Outlet } from 'react-router-dom';

function App() {
  return (
    <div className="App">
      <NavBar />
      <Outlet />
    </div>
  );
}

export default App;
