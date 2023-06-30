import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';
import reportWebVitals from './reportWebVitals';
import {createBrowserRouter, RouterProvider} from 'react-router-dom';
import Movies from './Layout/Movies';
import NewMovie from './Components/NewMovie';
import EditMovie from './Components/EditMovie';
import MovieDetails from './Components/MovieDetails';

const router = createBrowserRouter([
  {
    path: '/',
    element: <App />,
    children: [
      {
        index: true,
        element: <Movies />,
      },
      {
        path: 'movie/add/',
        element: <NewMovie />,
      },
      {
        path: 'movie/:id/',
        element: <MovieDetails />,
      },
      {
        path: 'movie/:id/edit/',
        element: <EditMovie />,
      }
    ]
  },
]);



const root = ReactDOM.createRoot(document.getElementById('root'));

root.render(
  <React.StrictMode>
    <RouterProvider router={router} />
  </React.StrictMode>
);

// If you want to start measuring performance in your app, pass a function
// to log results (for example: reportWebVitals(console.log))
// or send to an analytics endpoint. Learn more: https://bit.ly/CRA-vitals
reportWebVitals();
