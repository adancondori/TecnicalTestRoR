import axios from "axios";
import React, { useEffect, useState } from "react";
import { Link } from 'react-router-dom';

const FeaturesList = () => {
  const [features, setFeatures] = useState([]);
  const [currentPage, setCurrentPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [magType, setMagType] = useState('');

  useEffect(() => {
    fetchFeatures();
  }, [currentPage, magType]);

  const fetchFeatures = () => {
    let url = `http://localhost:3001/api/v1/features?page=${currentPage}&per_page=10`;
    if (magType) {
      url += `&filters[mag_type]=${magType}`;
    }

    axios
      .get(url)
      .then((response) => {
        setFeatures(response.data.data);
        setTotalPages(response.data.pagination.total);
      })
      .catch((err) => {
        console.error(err);
      });
  };

  const handleNextPage = () => {
    setCurrentPage((prevPage) => prevPage + 1);
  };

  const handlePrevPage = () => {
    setCurrentPage((prevPage) => prevPage - 1);
  };
  const handleSearch = () => {
    setCurrentPage(1);
    fetchFeatures();
  };
  return (
    <>
      <div className="container">
        <h1>All Features</h1>
        <label for="exampleInputEmail1" class="form-label">Filter by Mag Type</label>
        <input type="text" class="form-control" value={magType} onChange={(e) => setMagType(e.target.value)} placeholder="md, ml, ms, mw, me, mi, mb, mlg" />
      </div>
      <div className="container mt-5">
        {features.map((feature) => (
          <div key={feature.id} className="card mb-3">
            <div className="card-body">
              <h5 className="card-title"><strong>{feature.title}</strong></h5>
              <p className="card-text">
                <strong>Place:</strong> {feature.place}
              </p>
              <p className="card-text">
                <strong>URL:</strong>{" "}
                <a href={feature.external_url} target="_blank" rel="noopener noreferrer">
                  {feature.external_url}
                </a>
              </p>
              <p className="card-text">
                <strong>Magnitude:</strong> {feature.magnitude}
              </p>
              <p className="card-text">
                <strong>MagType:</strong> {feature.mag_type}
              </p>
              <p className="card-text">
                <strong>Latitude:</strong> {feature.coordinates.latitude}
              </p>
              <p className="card-text">
                <strong>Longitude:</strong> {feature.coordinates.longitude}
              </p>
              <Link to={`/comments/${feature.id}`} className="btn btn-primary">Add Comment</Link>
            </div>
          </div>
        ))}
      </div>
      <nav aria-label="Pagination">
        <ul className="pagination justify-content-center mt-3">
          <li className={`page-item ${currentPage === 1 ? 'disabled' : ''}`}>
            <button className="page-link" onClick={handlePrevPage} disabled={currentPage === 1}>Previous</button>
          </li>
          <li className="page-item">
            <span className="page-link">{`Page ${currentPage} of ${totalPages}`}</span>
          </li>
          <li className={`page-item ${currentPage === totalPages ? 'disabled' : ''}`}>
            <button className="page-link" onClick={handleNextPage} disabled={currentPage === totalPages}>Next</button>
          </li>
        </ul>
      </nav>
    </>
  );
};

export default FeaturesList;