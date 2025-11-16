import React from 'react';
import { useNavigate } from 'react-router-dom';
import styles from '../styles/Header.module.css';

const Header = ({ hideStudentButton }) => {
  const navigate = useNavigate();

  const goToStudents = () => {
    navigate('/students');
  };

  return (
    <header className={styles.header}>
      <h1 className={styles.title}>매아리</h1>
      {!hideStudentButton && (
        <button onClick={goToStudents} className={styles.studentsButton}>학생 목록</button>
      )}
    </header>
  );
};

export default Header;
