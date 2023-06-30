import React from 'react'
import { useOutletContext } from 'react-router-dom';
import MovieCard from '../Components/MovieCard';

const Movies = () =>{
    const { movies } = useOutletContext();

  return (
    <div>
        {movies && movies.map((movie) => (
            <MovieCard key={movie.id} movie={movie} />
        ))}
    </div>

  )
}

export default Movies


// const Home = () => {
//     const { blogs } = useOutletContext();

//     return (
//         <div>
//             {blogs && blogs.map((blog) => (
//                 <BlogCard key={blog.id} blog={blog} />
//             ))}
//         </div>
//     );
// };

// export default Home;