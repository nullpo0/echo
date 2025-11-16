import React, { useState, useEffect, useMemo } from 'react';
import { callAPI } from '../api';
import StudentCard from '../components/StudentCard';
import Header from '../components/Header'; // Import Header
import styles from '../styles/students.module.css';

const Students = () => {
  const [students, setStudents] = useState([]);
  const [filters, setFilters] = useState({
    danger: true,
    warning: true,
    safe: true,
  });

  useEffect(() => {
    const fetchStudents = async () => {
      try {
        const data = await callAPI('/get_stds', 'GET');
        if (data) {
          setStudents(data);
        }
      } catch (error) {
        console.error("Failed to fetch students:", error);
      }
    };

    fetchStudents();
  }, []);

  const handleFilterChange = (event) => {
    const { name, checked } = event.target;
    setFilters(prevFilters => ({
      ...prevFilters,
      [name]: checked,
    }));
  };

  const filteredStudents = useMemo(() => {
    return students.filter(student => {
      const { danger_mean } = student;
      if (danger_mean >= 80 && filters.danger) return true;
      if (danger_mean >= 50 && danger_mean < 80 && filters.warning) return true;
      if (danger_mean < 50 && filters.safe) return true;
      return false;
    });
  }, [students, filters]);

  return (
    <div className={styles.page}>
      <Header hideStudentButton={true} /> {/* Pass prop to hide button */}
      <div className={styles.filters}>
        <button
          className={`${styles.filterButton} ${styles.danger} ${filters.danger ? styles.active : ''}`}
          onClick={() => handleFilterChange({ target: { name: 'danger', checked: !filters.danger } })}
        >
          <input
            type="checkbox"
            name="danger"
            checked={filters.danger}
            onChange={handleFilterChange}
            style={{ display: 'none' }} // Hidden, but still handles state
          />
          위험
        </button>
        <button
          className={`${styles.filterButton} ${styles.warning} ${filters.warning ? styles.active : ''}`}
          onClick={() => handleFilterChange({ target: { name: 'warning', checked: !filters.warning } })}
        >
          <input
            type="checkbox"
            name="warning"
            checked={filters.warning}
            onChange={handleFilterChange}
            style={{ display: 'none' }} // Hidden, but still handles state
          />
          주의
        </button>
        <button
          className={`${styles.filterButton} ${styles.safe} ${filters.safe ? styles.active : ''}`}
          onClick={() => handleFilterChange({ target: { name: 'safe', checked: !filters.safe } })}
        >
          <input
            type="checkbox"
            name="safe"
            checked={filters.safe}
            onChange={handleFilterChange}
            style={{ display: 'none' }} // Hidden, but still handles state
          />
          정상
        </button>
      </div>
      <main className={styles.studentList}>
        {filteredStudents.map(student => (
          <StudentCard key={student.s_id} student={student} />
        ))}
      </main>
    </div>
  );
};

export default Students;
