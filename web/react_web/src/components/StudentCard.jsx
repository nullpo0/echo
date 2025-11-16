import React from 'react';
import { useNavigate } from 'react-router-dom';
import styles from '../styles/StudentCard.module.css';

const StudentCard = ({ student }) => {
  const { s_id, name, danger_mean } = student;
  const navigate = useNavigate();

  let statusClass = '';
  let statusText = '';

  if (danger_mean >= 80) {
    statusClass = styles.danger;
    statusText = '위험';
  } else if (danger_mean >= 50) {
    statusClass = styles.warning;
    statusText = '주의';
  } else {
    statusClass = styles.safe;
    statusText = '정상';
  }

  const handleClick = () => {
    navigate(`/diaries/${s_id}`, { state: { name, danger_mean } });
  };

  return (
    <button className={`${styles.card} ${statusClass}`} onClick={handleClick}>
      <div className={styles.name}>{name}</div>
      <div className={styles.status}>{statusText}</div>
    </button>
  );
};

export default StudentCard;
