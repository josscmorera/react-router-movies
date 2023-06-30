import React from 'react'
import { Link } from 'react-router-dom';

function MovieCard({ movie }) {
    return (
        <div>
            <Link to={`/movies/${movie.id}`}>
                <img src={movie.posterUrl} />
            </Link>
            <h2>{movie.title} - {movie.year}</h2>
            <h3>Director: {movie.director}</h3>
        </div>
    )
}

export default MovieCard