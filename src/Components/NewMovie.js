import React, { useState } from 'react'
import { useNavigate, useOutletContext } from 'react-router-dom'
import { v4 as uuidv4 } from 'uuid'

function NewMovie() {
    const navigate = useNavigate();
    const { setMovies } = useOutletContext();
    const [movie, setMovie] = useState({
        id: '',
        title: '',
        year: '',
        runtime: '',
        genres: '',
        director: '',
        actors: '',
        plot: '',
        posterUrl: '',
    });

    const handleChange = (e) => {
        const { name, value } = e.target;
        setMovie({ ...movie, [name]: value });
    };

    const handleSubmit = (e) => {
        e.preventDefault();
        const newMovie = { ...movie, id: uuidv4() };
        setMovies(prevMovies => [...prevMovies, newMovie]);
        navigate('/');
    };

    return (
        <form onSubmit={handleSubmit}>
            <label>
                Title:
                <input type="text" name="title" value={movie.title} onChange={handleChange} required />
            </label>
            <label>
                Year:
                <input type="number" name="year" value={movie.year} onChange={handleChange} required />
            </label>
            <label>
                Runtime:
                <input type="number" name="runtime" value={movie.runtime} onChange={handleChange} required />
            </label>
            <label>
                Genres:
                <input type="text" name="genres" value={movie.genres} onChange={handleChange} required />
            </label>
            <label>
                Director:
                <input type="text" name="director" value={movie.director} onChange={handleChange} required />
            </label>
            <label>
                Actors:
                <input type="text" name="actors" value={movie.actors} onChange={handleChange} required />
            </label>
            <label>
                Plot:
                <textarea name="plot" value={movie.plot} onChange={handleChange} required />
            </label>
            <label>
                Poster URL:
                <input type="text" name="posterUrl" value={movie.posterUrl} onChange={handleChange} required />
            </label>
            <button type="submit">Add Movie</button>
        </form>
    )
}

export default NewMovie