import React from 'react'
import { Link } from 'react-router-dom'

function MovieCard({ movie }) {
    return (
        <div>
            <br />
            <h2>{movie.title} - {movie.year}</h2>
            <Link to={`/movie/${movie.id}`}>
                <img src={movie.posterUrl} />
            </Link>

        </div>
    )
}

export default MovieCard