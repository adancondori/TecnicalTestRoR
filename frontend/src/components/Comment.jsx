import axios from "axios";
import React, { useState } from "react";
import { useParams, useNavigate} from "react-router-dom";


const Comment = () => {
  const [commentBody, setCommentBody] = useState("");
  const { featureId } = useParams();
  const navigate = useNavigate();

  const submitComment = () => {
    axios.post(`http://localhost:3001/api/v1/features/${featureId}/comments`, {
      comment: { body: commentBody }
    })
    .then(() => {
      alert('Comentario agregado con éxito.');
      navigate('/features');
    })
    .catch((error) => {
      console.error('Error al enviar el comentario:', error);
      alert('Error al agregar el comentario.');
    });
  };

  return (
    <div className="container mt-5">
      <h2>Agregar un Comentario</h2>
      <textarea
        className="form-control"
        value={commentBody}
        onChange={(e) => setCommentBody(e.target.value)}
        placeholder="Escribe tu comentario aquí..."
        rows="3"
      />
      <button onClick={submitComment} className="btn btn-primary mt-3">
        Enviar Comentario
      </button>
    </div>
  );
};

export default Comment;
