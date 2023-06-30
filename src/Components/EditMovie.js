import { useState, useEffect } from 'react'
import { useOutletContext } from 'react-router-dom'
import { useParams, useNavigate } from 'react-router-dom'

function EditMovie() {
    const navigate = useNavigate();
    const { id } = useParams();
    const { movies, setMovies } = useOutletContext();
    const [ movie, setMovie ] = useState({
        title: '',
        year: '',
        runtime: '',
        genres: '',
        director: '',
        actors: '',
        plot: '',
        posterUrl: '',
    });

    useEffect(() => {
        const movieToEdit = movies.find(movie => movie.id === id);
        if (movieToEdit) {
            setMovie(movieToEdit);
        } else {
            navigate('/');
        }
    }, [id, movies, navigate]);

    const handleChange = (e) => {
        const { name, value } = e.target;
        setMovie({ ...movie, [name]: value });
    };

    const handleSubmit = (e) => {
        e.preventDefault();
        setMovies(prevMovies => prevMovies.map(m => m.id === id ? movie : m));
        navigate(`/movie/${id}`);
    };

    const handleDelete = () => {
        setMovies(prevMovies => prevMovies.filter(m => m.id !== id));
        navigate('/');
    };

    return (
        <form onSubmit={handleSubmit}>
            <br />
            <br />
            <label>
                Title:
                <input type="text" name="title" value={movie.title} onChange={handleChange} required />
            </label>
            <br />
            <br />
            <label>
                Year:
                <input type="text" name="year" value={movie.year} onChange={handleChange} required />
            </label>
            <br />
            <br />
            <label>
                Runtime:
                <input type="text" name="runtime" value={movie.runtime} onChange={handleChange} required />
            </label>
            <br />
            <br />
            <label>
                Genres:
                <input type="text" name="genres" value={movie.genres} onChange={handleChange} required />
            </label>
            <br />
            <br />
            <label>
                Director:
                <input type="text" name="director" value={movie.director} onChange={handleChange} required />
            </label>
            <br />
            <br />
            <label>
                Actors:
                <input type="text" name="actors" value={movie.actors} onChange={handleChange} required />
            </label>
            <br />
            <br />
            <label>
                Plot:
                <textarea name="plot" value={movie.plot} onChange={handleChange} required />
            </label>
            <br />
            <br />
            <label>
                Poster URL:
                <input type="text" name="posterUrl" value={movie.posterUrl} onChange={handleChange} required />
            </label>
            <br />
            <br />
            <button type="submit">Update Movie</button>
            <br />
            <br />
            <button type="button" onClick={handleDelete}>Delete Movie</button>
        </form>
    )
}

export default EditMovie