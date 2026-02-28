const Home = () => {
  return (
    <div className="container mt-5">
      <div className="row justify-content-center">
        <div className="col-md-8 text-center">
          <h1 className="display-4 mb-4">Technical Test</h1>
          <p className="lead text-muted">
            Ready to start building.
          </p>
          <hr className="my-4" />
          <p className="text-muted">
            This is a base project with Rails API backend, React frontend, MySQL database, and Nginx reverse proxy.
            All running with Docker Compose.
          </p>
          <div className="mt-4">
            <span className="badge bg-primary me-2">Rails 7</span>
            <span className="badge bg-info me-2">React</span>
            <span className="badge bg-warning me-2">MySQL 8</span>
            <span className="badge bg-success me-2">Docker</span>
            <span className="badge bg-secondary">Nginx</span>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Home;
