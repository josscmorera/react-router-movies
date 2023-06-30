import React from 'react'
import { Link } from 'react-router-dom'

function NavBar() {
    return (
        <nav>
            <Link to="/">Movie List</Link>&nbsp;
            <Link to="/movie/add/">Add New Movie</Link>&nbsp;
        </nav>
    )
}

export default NavBar