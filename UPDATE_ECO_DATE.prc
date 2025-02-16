CREATE OR REPLACE PROCEDURE APPS.update_eco_date (
   p_error_buff             OUT      VARCHAR2,
   p_error_code             OUT      NUMBER,
   p_change_notice          IN       VARCHAR2,
   p_old_effectivity_date   IN       DATE,
   p_effectivity_date       IN       VARCHAR2
)
AS
   v_date_found                NUMBER (10);
   flag                        NUMBER (10);
   v_eco_mtl_count             NUMBER (20);
   v_date_rev                  NUMBER (20);
   v_mtl_rev_count             NUMBER (20);
   v_eri                       VARCHAR2 (20);
   v_bcb                       VARCHAR2 (20);
   v_mtl                       VARCHAR2 (20);
   v_mtl_rev                   VARCHAR2 (20);
   v_user_id                   VARCHAR2 (10);
   v_new_effec                 DATE;
   v_sysdate                   DATE;
   v_effectivity_date          VARCHAR2 (20);
   v_old_effectivity_date      VARCHAR2 (20);
   v_change_notice_count       NUMBER;
   v_change_notice_count_bcb   NUMBER (20);
   v_change_notice_count_mtl   NUMBER (20);
   v_date_count                NUMBER;
   user_name                   VARCHAR2 (10) := NULL;
BEGIN
/************************************************************************
                     Author - Mitali Lohar
                     Purpose - Updating old ECO effectivity date
                     Creation-date - 15-may-2024
*******************************************************************/
   v_effectivity_date := p_effectivity_date;
   v_new_effec := TO_DATE (p_effectivity_date, 'YYYY/MM/DD HH24:MI:SS');
   --y := TO_DATE (SYSDATE, 'DD/MM/YYYY HH24:MI:SS');
   v_sysdate := SYSDATE;
   v_old_effectivity_date := TO_CHAR (p_old_effectivity_date, 'DD-MON-YYYY');
   fnd_file.put_line (fnd_file.output,
                      'Old effectivity date: ' || v_old_effectivity_date
                     );
   fnd_file.put_line (fnd_file.output,
                      'New effectivity date: ' || v_effectivity_date
                     );

   /*fnd_file.put_line (fnd_file.output, 'v_new_effec and v_sysdate : ' || v_new_effec || ' ' || v_sysdate);*/
   IF TO_DATE (p_old_effectivity_date, 'DD-MON-YYYY') <=
                                              TO_DATE (SYSDATE, 'DD-MON-YYYY')
   THEN
      p_error_code := 2;
      fnd_file.put_line
         (fnd_file.output,
          'The old effectivity date should be greater than present/system date, enter future date.'
         );
      RETURN;
   END IF;

   IF v_new_effec <= v_sysdate
   THEN
      p_error_code := 2;
      fnd_file.put_line
         (fnd_file.output,
          'The new effectivity date should be greater than present/system date, enter future date.'
         );
      RETURN;
   END IF;

   BEGIN
      v_user_id := fnd_global.user_id;
      fnd_file.put_line (fnd_file.output, 'INPUT PARAMETERS:-');
      fnd_file.put_line (fnd_file.output, '');
      /*fnd_file.put_line (fnd_file.output,
                         'Old effectivity date: ' || v_old_effectivity_date
                        );
      fnd_file.put_line (fnd_file.output,
                         'New effectivity date: ' || v_effectivity_date
                        );*/
      fnd_file.put_line (fnd_file.output, 'The user id is ' || v_user_id);
      fnd_file.put_line (fnd_file.output, '');
      fnd_file.put_line
         (fnd_file.output,
          '----------------------------------------------------------------------------------'
         );
      fnd_file.put_line (fnd_file.output, '');

      BEGIN
         SELECT COUNT (*)
           INTO v_change_notice_count
           FROM eng_revised_items
          WHERE change_notice = p_change_notice;
      EXCEPTION
         WHEN OTHERS
         THEN
            v_change_notice_count := 0;
      END;

      fnd_file.put_line
         (fnd_file.output,
             'Number of rows fetched for this ECO in eng_revised_items(change_notice) is : '
          || v_change_notice_count
         );

      BEGIN
         SELECT COUNT (*)
           INTO v_change_notice_count_bcb
           FROM bom_components_b
          WHERE change_notice = p_change_notice;
      EXCEPTION
         WHEN OTHERS
         THEN
            v_change_notice_count_bcb := 0;
      END;

      fnd_file.put_line
         (fnd_file.output,
             'Number of rows fetched for this ECO in bom_components_b(change_notice) is : '
          || v_change_notice_count_bcb
         );

      BEGIN
         SELECT COUNT (*)
           INTO v_change_notice_count_mtl
           FROM mtl_item_revisions_b
          WHERE change_notice = p_change_notice;

         IF v_change_notice_count_mtl = 0
         THEN
            BEGIN
               SELECT COUNT (*)
                 INTO v_eco_mtl_count
                 FROM mtl_item_revisions_b
                WHERE attribute14 = p_change_notice;
            EXCEPTION
               WHEN OTHERS
               THEN
                  v_change_notice_count_mtl := 0;
                  v_eco_mtl_count := 0;
            END;
         END IF;
      END;

      fnd_file.put_line
         (fnd_file.output,
             'Number of rows fetched for this ECO in mtl_item_revisions_b (change_notice) is : '
          || v_change_notice_count_mtl
         );

      IF (    v_change_notice_count = 0
          AND v_change_notice_count_bcb = 0
          AND v_change_notice_count_mtl = 0
          AND v_eco_mtl_count = 0
         )
      THEN
         fnd_file.put_line
            (fnd_file.output,
             '----------------------------------------------------------------------------------'
            );
         fnd_file.put_line (fnd_file.output,
                            p_change_notice
                            || ' Change notice does not exist.'
                           );
         p_error_code := 2;
         RETURN;
      END IF;

      fnd_file.put_line
         (fnd_file.output,
             'Number of rows fetched for this ECO in MTL_ITEM_REVISIONS_B (attribute14) is : '
          || NVL (v_eco_mtl_count, 0)
         );
      fnd_file.put_line (fnd_file.output, '');
      fnd_file.put_line (fnd_file.output,
                         'The ECO Number: ' || p_change_notice
                        );

      BEGIN
         SELECT COUNT (*)
           INTO v_date_count
           FROM eng_revised_items
          WHERE change_notice = p_change_notice
            AND TRUNC (scheduled_date) = TRUNC (p_old_effectivity_date);

         IF v_date_count = 0
         THEN
            BEGIN
               SELECT COUNT (*)
                 INTO v_date_rev
                 FROM mtl_item_revisions_b
                WHERE attribute14 = p_change_notice
                  AND TRUNC (effectivity_date) =
                                                TRUNC (p_old_effectivity_date);
            EXCEPTION
               WHEN OTHERS
               THEN
                  v_date_count := 0;
                  v_date_rev := 0;
            END;
         END IF;
      END;

      fnd_file.put_line
         (fnd_file.output,
             'Number of rows fetched for ECO and old effectivity date in ENG_REVISED_ITEMS is : '
          || v_date_count
         );

      IF    (v_date_count = 0 AND v_date_rev = 0)
         OR (    v_change_notice_count = 0
             AND v_change_notice_count_bcb = 0
             AND (v_change_notice_count_mtl = 0 AND v_mtl_rev_count = 0)
            )
      THEN
         fnd_file.put_line
            (fnd_file.output,
             '----------------------------------------------------------------------------------'
            );
         fnd_file.put_line
                      (fnd_file.output,
                       'No data found, please verify the old effectivity date'
                      );
         p_error_code := 2;
         RETURN;
      END IF;



      BEGIN
         apps.check_revision_item_date
                           (p_change_notice             => p_change_notice,
                            p_old_effectivity_date      => p_old_effectivity_date,
                            p_new_effectivity_date      => v_new_effec,
                            v_flag                      => flag
                                                              -- Add this line
                           );
      EXCEPTION
         WHEN OTHERS
         THEN
            flag := 0;
      END;


      IF flag = 0
      THEN
         fnd_file.put_line
               (fnd_file.output,
                '-----------------------------------------------------------'
               );
         fnd_file.put_line (fnd_file.output, '');
         fnd_file.put_line
                   (fnd_file.output,
                    'Please enter correct effectivity date for item revision.'
                   );
         p_error_code := 2;
         RETURN;
      END IF;



--updating mtl_item_revisions_b
      IF (v_eco_mtl_count != 0 AND v_date_rev != 0)
      THEN
         UPDATE mtl_item_revisions_b
            SET effectivity_date =
                         TO_DATE (v_effectivity_date, 'YYYY/MM/DD HH24:MI:SS')
          WHERE TRUNC (effectivity_date) =
                               TO_DATE (v_old_effectivity_date, 'DD-MON-YYYY')
            AND implementation_date IS NOT NULL
            AND attribute14 = p_change_notice;

         DECLARE
            v_row_count   NUMBER;
         BEGIN
            v_row_count := SQL%ROWCOUNT;
            COMMIT;
            -- Print the count of rows updated
            fnd_file.put_line
               (fnd_file.output,
                '----------------------------------------------------------------------------------'
               );
            fnd_file.put_line (fnd_file.output, '');
            fnd_file.put_line
               (fnd_file.output,
                   ' Rows updated in MTL_ITEM_REVISIONS_B for item revisions: '
                || v_row_count
               );
         END;
      END IF;

      /*IF    (v_date_count = 0 AND v_date_rev = 0)
         OR (    v_change_notice_count = 0
             AND v_change_notice_count_bcb = 0
             AND (v_change_notice_count_mtl = 0 AND v_mtl_rev_count = 0)
            )
      THEN
         fnd_file.put_line
            (fnd_file.output,
             '----------------------------------------------------------------------------------'
            );
         fnd_file.put_line
                      (fnd_file.output,
                       'No data found, please verify the old effectivity date'
                      );
         p_error_code := 2;
         RETURN;
      END IF;*/

      fnd_file.put_line (fnd_file.output, '');

      INSERT INTO xx_eng_revised_items_bk
         SELECT item.*, v_user_id, SYSDATE
           FROM eng_revised_items item
          WHERE change_notice = p_change_notice;

      INSERT INTO xx_bom_components_b_bk
         SELECT comp.*, v_user_id, SYSDATE
           FROM bom_components_b comp
          WHERE change_notice = p_change_notice;

      INSERT INTO xx_mtl_item_revisions_bk
         SELECT rev.*, v_user_id, SYSDATE
           FROM mtl_item_revisions rev
          WHERE change_notice = p_change_notice;

      fnd_file.put_line
         (fnd_file.output,
          '----------------------------------------------------------------------------------'
         );

      UPDATE bom_components_b
         SET effectivity_date =
                         TO_DATE (v_effectivity_date, 'YYYY/MM/DD HH24:MI:SS')
       WHERE change_notice = p_change_notice
         AND acd_type = 1
         AND TRUNC (effectivity_date) =
                               TO_DATE (v_old_effectivity_date, 'DD-MON-YYYY')
         AND implementation_date IS NOT NULL;

      DECLARE
         v_row_count   NUMBER;
      BEGIN
         v_row_count := SQL%ROWCOUNT;
         COMMIT;
         -- Print the count of rows updated
         fnd_file.put_line (fnd_file.output,
                               '1. Rows updated in BOM_COMPONENTS_B : '
                            || v_row_count
                           );
      END;

      COMMIT;

      UPDATE eng_revised_components
         SET effectivity_date =
                         TO_DATE (v_effectivity_date, 'YYYY/MM/DD HH24:MI:SS')
       WHERE change_notice = p_change_notice
         AND acd_type = 1
         AND TRUNC (effectivity_date) =
                               TO_DATE (v_old_effectivity_date, 'DD-MON-YYYY')
         AND implementation_date IS NOT NULL;

      DECLARE
         v_row_count   NUMBER;
      BEGIN
         v_row_count := SQL%ROWCOUNT;
         COMMIT;
         -- Print the count of rows updated
         fnd_file.put_line (fnd_file.output,
                               '2. Rows updated in ENG_REVISED_COMPONENTS: '
                            || v_row_count
                           );
      END;

      COMMIT;

      UPDATE bom_components_b
         SET effectivity_date =
                         TO_DATE (v_effectivity_date, 'YYYY/MM/DD HH24:MI:SS')
       WHERE change_notice = p_change_notice
         AND acd_type = 2
         AND TRUNC (effectivity_date) =
                               TO_DATE (v_old_effectivity_date, 'DD-MON-YYYY')
         AND implementation_date IS NOT NULL;

      DECLARE
         v_row_count   NUMBER;
      BEGIN
         v_row_count := SQL%ROWCOUNT;
         COMMIT;
         -- Print the count of rows updated
         fnd_file.put_line (fnd_file.output,
                               '3. Rows updated in BOM_COMPONENTS_B: '
                            || v_row_count
                           );
      END;

      COMMIT;

      UPDATE bom_components_b
         SET disable_date =
                         TO_DATE (v_effectivity_date, 'YYYY/MM/DD HH24:MI:SS')
       WHERE change_notice = p_change_notice
         AND acd_type = 2
         AND TRUNC (disable_date) =
                               TO_DATE (v_old_effectivity_date, 'DD-MON-YYYY')
         AND implementation_date IS NOT NULL;

      DECLARE
         v_row_count   NUMBER;
      BEGIN
         v_row_count := SQL%ROWCOUNT;
         COMMIT;
         -- Print the count of rows updated
         fnd_file.put_line (fnd_file.output,
                               '4. Rows updated in BOM_COMPONENTS_B: '
                            || v_row_count
                           );
      END;

      COMMIT;

      UPDATE bom_components_b
         SET disable_date =
                         TO_DATE (v_effectivity_date, 'YYYY/MM/DD HH24:MI:SS')
       WHERE change_notice = p_change_notice
         AND acd_type IS NULL
         AND TRUNC (disable_date) =
                               TO_DATE (v_old_effectivity_date, 'DD-MON-YYYY')
         AND implementation_date IS NOT NULL;

      DECLARE
         v_row_count   NUMBER;
      BEGIN
         v_row_count := SQL%ROWCOUNT;
         COMMIT;
         -- Print the count of rows updated
         fnd_file.put_line (fnd_file.output,
                               '5. Rows updated in BOM_COMPONENTS_B: '
                            || v_row_count
                           );
      END;

      COMMIT;

      UPDATE eng_revised_components
         SET effectivity_date =
                         TO_DATE (v_effectivity_date, 'YYYY/MM/DD HH24:MI:SS')
       WHERE change_notice = p_change_notice
         AND acd_type = 2
         AND TRUNC (effectivity_date) =
                               TO_DATE (v_old_effectivity_date, 'DD-MON-YYYY')
         AND implementation_date IS NOT NULL;

      DECLARE
         v_row_count   NUMBER;
      BEGIN
         v_row_count := SQL%ROWCOUNT;
         COMMIT;
         -- Print the count of rows updated
         fnd_file.put_line (fnd_file.output,
                               '6. Rows updated in ENG_REVISED_COMPONENTS: '
                            || v_row_count
                           );
      END;

      COMMIT;

      UPDATE mtl_item_revisions_b
         SET effectivity_date =
                         TO_DATE (v_effectivity_date, 'YYYY/MM/DD HH24:MI:SS')
       WHERE change_notice = p_change_notice
         AND TRUNC (effectivity_date) =
                               TO_DATE (v_old_effectivity_date, 'DD-MON-YYYY')
         AND implementation_date IS NOT NULL;

      DECLARE
         v_row_count   NUMBER;
      BEGIN
         v_row_count := SQL%ROWCOUNT;
         COMMIT;
         -- Print the count of rows updated
         fnd_file.put_line (fnd_file.output,
                               '7. Rows updated in MTL_ITEM_REVISIONS_B: '
                            || v_row_count
                           );
      END;

      COMMIT;

      UPDATE eng_revised_items
         SET scheduled_date =
                         TO_DATE (v_effectivity_date, 'YYYY/MM/DD HH24:MI:SS')
       WHERE change_notice = p_change_notice
         AND TRUNC (scheduled_date) =
                               TO_DATE (v_old_effectivity_date, 'DD-MON-YYYY');

      DECLARE
         v_row_count   NUMBER;
      BEGIN
         v_row_count := SQL%ROWCOUNT;
         COMMIT;
         -- Print the count of rows updated
         fnd_file.put_line (fnd_file.output,
                               '8. Rows updated in ENG_REVISED_ITEMS: '
                            || v_row_count
                           );
      END;

      COMMIT;

      UPDATE bom_components_b
         SET disable_date =
                         TO_DATE (v_effectivity_date, 'YYYY/MM/DD HH24:MI:SS')
       WHERE change_notice = p_change_notice
         AND acd_type = 1
         AND TRUNC (disable_date) =
                               TO_DATE (v_old_effectivity_date, 'DD-MON-YYYY')
         AND implementation_date IS NOT NULL;

      DECLARE
         v_row_count   NUMBER;
      BEGIN
         v_row_count := SQL%ROWCOUNT;
         COMMIT;
         -- Print the count of rows updated
         fnd_file.put_line (fnd_file.output,
                               '9. Rows updated in BOM_COMPONENTS_B: '
                            || v_row_count
                           );
      END;

      COMMIT;

      UPDATE eng_revised_components
         SET disable_date =
                         TO_DATE (v_effectivity_date, 'YYYY/MM/DD HH24:MI:SS')
       WHERE change_notice = p_change_notice
         AND acd_type = 3
         AND TRUNC (effectivity_date) =
                               TO_DATE (v_old_effectivity_date, 'DD-MON-YYYY')
         AND implementation_date IS NOT NULL;

      DECLARE
         v_row_count   NUMBER;
      BEGIN
         v_row_count := SQL%ROWCOUNT;
         COMMIT;
         -- Print the count of rows updated
         fnd_file.put_line (fnd_file.output,
                               '10. Rows updated in ENG_REVISED_COMPONENTS: '
                            || v_row_count
                           );
      END;

      COMMIT;

      UPDATE mtl_item_revisions_b
         SET effectivity_date =
                         TO_DATE (v_effectivity_date, 'YYYY/MM/DD HH24:MI:SS')
       WHERE TRUNC (effectivity_date) =
                               TO_DATE (v_old_effectivity_date, 'DD-MON-YYYY')
         AND implementation_date IS NOT NULL
         AND inventory_item_id IN (SELECT eri.revised_item_id
                                     FROM eng_revised_items eri
                                    WHERE change_notice = p_change_notice);

      DECLARE
         v_row_count   NUMBER;
      BEGIN
         v_row_count := SQL%ROWCOUNT;
         COMMIT;
         -- Print the count of rows updated
         fnd_file.put_line (fnd_file.output,
                               '11. Rows updated in MTL_ITEM_REVISIONS_B: '
                            || v_row_count
                           );
      END;

      COMMIT;

      UPDATE mtl_item_revisions_b
         SET effectivity_date =
                         TO_DATE (v_effectivity_date, 'YYYY/MM/DD HH24:MI:SS')
       WHERE TRUNC (effectivity_date) =
                               TO_DATE (v_old_effectivity_date, 'DD-MON-YYYY')
         AND implementation_date IS NOT NULL
         AND attribute14 = p_change_notice;

      DECLARE
         v_row_count   NUMBER;
      BEGIN
         v_row_count := SQL%ROWCOUNT;
         COMMIT;
         -- Print the count of rows updated
         fnd_file.put_line (fnd_file.output,
                               '12. Rows updated in MTL_ITEM_REVISIONS_B : '
                            || v_row_count
                           );
      END;

      fnd_file.put_line (fnd_file.output, '');
      COMMIT;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         fnd_file.put_line (fnd_file.LOG,
                            'No data found, please verify the inputs.'
                           );
         fnd_file.put_line
            (fnd_file.output,
             '----------------------------------------------------------------------------------'
            );
         fnd_file.put_line (fnd_file.output,
                            'No data found, please verify the inputs.'
                           );
         p_error_code := 2;
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, 'An error occurred: ' || SQLERRM);
         fnd_file.put_line (fnd_file.output,
                            'An error occurred: ' || SQLERRM);
         p_error_code := 2;
   END;
END update_eco_date;
/
