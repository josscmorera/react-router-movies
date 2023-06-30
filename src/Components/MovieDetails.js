import React from 'react'
import { useParams, useOutletContext } from 'react-router-dom'

function MovieDetails() {
    const { id } = useParams();
    const { movies } = useOutletContext();
    const movie = movies.find(movie => movie.id === id);

    return (
        <div>
            <br />
            <img src={movie.posterUrl} alt={movie.title} />
            <br />
            <h1>{movie.title} - {movie.year}</h1>
            <p>Runtime: {movie.runtime}</p>
            <p>Genres: {movie.genres}</p>
            <p>Director: {movie.director}</p>
            <p>Actors: {movie.actors}</p>
            <p>Plot: {movie.plot}</p>
        </div>
    );
}

export default MovieDetails;
