/* Formatted on 2024/11/11 14:20 (Formatter Plus v4.8.8) */
CREATE OR REPLACE PROCEDURE apps.check_revision_item_date (
   p_change_notice          IN       VARCHAR2,
   p_old_effectivity_date   IN       DATE,
   p_new_effectivity_date   IN       DATE,
   v_flag                   OUT      NUMBER
)
AS
   CURSOR c_items (v_change_notice VARCHAR2, v_old_effectivity_date DATE)
   IS
      SELECT DISTINCT TRUNC (effectivity_date), mir.inventory_item_id,
                      msi.segment1
                 FROM mtl_item_revisions_b mir, mtl_system_items_b msi
                WHERE mir.inventory_item_id = msi.inventory_item_id
                  AND mir.organization_id = msi.organization_id
                  AND (   mir.change_notice = v_change_notice
                       OR mir.attribute14 = v_change_notice
                      )
                  AND TRUNC (mir.effectivity_date) =
                                                TRUNC (v_old_effectivity_date);

   dummy_date        mtl_item_revisions_b.effectivity_date%TYPE;
   v_item_id         mtl_system_items_b.inventory_item_id%TYPE;
   v_segment1        mtl_system_items_b.segment1%TYPE;

   CURSOR c_revisions (
      v_item_id   IN   mtl_item_revisions_b.inventory_item_id%TYPE
   )
   IS
      WITH distinct_revisions AS
           (SELECT   revision, inventory_item_id,
                     MAX (effectivity_date) AS effectivity_date
                FROM mtl_item_revisions_b
               WHERE inventory_item_id = v_item_id
                 AND (change_notice IS NOT NULL OR attribute14 IS NOT NULL)
            GROUP BY revision, inventory_item_id)
      SELECT   effectivity_date, revision, inventory_item_id
          FROM distinct_revisions
      ORDER BY revision;

   v_cur_eff_date    mtl_item_revisions_b.effectivity_date%TYPE;
   v_cur_rev_rev     mtl_item_revisions_b.revision%TYPE;
   v_cur_rev_id      mtl_item_revisions_b.inventory_item_id%TYPE;
   v_prev_eff_date   mtl_item_revisions_b.effectivity_date%TYPE;
   v_prev_rev_rev    mtl_item_revisions_b.revision%TYPE;
   v_prev_rev_id     mtl_item_revisions_b.inventory_item_id%TYPE;
   v_next_eff_date   mtl_item_revisions_b.effectivity_date%TYPE;
   v_next_rev_rev    mtl_item_revisions_b.revision%TYPE;
   v_next_rev_id     mtl_item_revisions_b.inventory_item_id%TYPE;
BEGIN
   DBMS_OUTPUT.put_line ('Procedure started.');
   v_flag := 0;

   OPEN c_items (p_change_notice, p_old_effectivity_date);

   DBMS_OUTPUT.put_line
                ('Opened cursor for items with change_notice or attribute14.');

   /*************************************************************************
                           AUTHOR NAME- Mitali Lohar
                           Date of creation- 12th july 2024
   **************************************************************************/
   LOOP
      FETCH c_items
       INTO dummy_date, v_item_id, v_segment1;

      EXIT WHEN c_items%NOTFOUND;
      DBMS_OUTPUT.put_line (   'Processing item: '
                            || v_item_id
                            || ', '
                            || v_segment1
                           );

      OPEN c_revisions (v_item_id);

      DBMS_OUTPUT.put_line (   'Opened cursor for revisions of item: '
                            || v_item_id
                           );

      FETCH c_revisions
       INTO v_cur_eff_date, v_cur_rev_rev, v_cur_rev_id;

      EXIT WHEN c_revisions%NOTFOUND;

      FETCH c_revisions
       INTO v_next_eff_date, v_next_rev_rev, v_next_rev_id;

      LOOP
         DBMS_OUTPUT.put_line ('Processing revision: ' || v_cur_rev_rev);

         -- Print the previous revision's effectivity date
         IF v_prev_eff_date IS NOT NULL
         THEN
            DBMS_OUTPUT.put_line ('Previous revision date: '
                                  || v_prev_eff_date
                                 );
         ELSE
            DBMS_OUTPUT.put_line ('Previous revision effectivity date: NULL');
         END IF;

         IF v_cur_eff_date IS NOT NULL
         THEN
            DBMS_OUTPUT.put_line ('Current revision date: ' || v_cur_eff_date);
         ELSE
            DBMS_OUTPUT.put_line ('Current revision date: NULL');
         END IF;

         -- Print the next revision's effectivity date
         IF v_next_eff_date IS NOT NULL
         THEN
            DBMS_OUTPUT.put_line ('Next revision date: ' || v_next_eff_date);
         ELSE
            DBMS_OUTPUT.put_line ('Next revision date: NULL');
         END IF;

         -- Check if the current old effectivity date matches the input parameter
         IF TRUNC (v_cur_eff_date) = p_old_effectivity_date
         THEN
            DBMS_OUTPUT.put_line (   'Matched old effectivity date: '
                                  || p_old_effectivity_date
                                 );

            -- Ensure the new effectivity date is greater than the previous revision's date
            IF c_revisions%NOTFOUND
            THEN
               -- Last row
               IF p_new_effectivity_date > v_prev_eff_date
               THEN
                  DBMS_OUTPUT.put_line ('Valid, last row, updated');
                  v_flag := 1;                      -- Set flag to 1 if valid
                  DBMS_OUTPUT.put_line ('Flag: ' || v_flag);
                  EXIT;
               ELSE
                  DBMS_OUTPUT.put_line
                     ('Please enter a valid effectivity date for item revisions.'
                     );
                  v_flag := 0;                     -- Set flag to 0 if invalid
                  DBMS_OUTPUT.put_line ('Flag: ' || v_flag);
                  RETURN;
               END IF;
            ELSE
            
               IF     p_new_effectivity_date < v_next_eff_date
                  AND p_new_effectivity_date > v_prev_eff_date
               THEN
                  DBMS_OUTPUT.put_line ('Valid, updated');
                  v_flag := 1;                      -- Set flag to 1 if valid
                  DBMS_OUTPUT.put_line ('Flag: ' || v_flag);
                  EXIT;
                  
               ELSIF v_cur_eff_date = v_next_eff_date
               THEN
                  -- Update the revision date in the function, if the update is successful, v_flag will be set to 1
                  v_flag :=
                     xx_update_high_rev_date (v_next_rev_id,
                                              p_new_effectivity_date
                                             );
                  -- Perform the operation and print the message
                  DBMS_OUTPUT.put_line
                     ('Two same revisions have same effectivity date, so only higher revision''s effectivity date is updated.'
                     );

                  -- Check if the update was successful (i.e., flag is 1)
                  IF v_flag = 1
                  THEN
                     -- Exit the whole process as the update is already done
                     DBMS_OUTPUT.put_line
                                  ('Update performed. Exiting the procedure.');
                     RETURN;      -- This will exit the procedure immediately
                  ELSE
                     -- If flag is not 1, proceed further (this might happen if there was an issue with the update)
                     DBMS_OUTPUT.put_line ('Update failed or not performed.');
                  END IF;

                  EXIT;
               ELSE
                  DBMS_OUTPUT.put_line
                     ('Please enter a valid effectivity date for item revisions.'
                     );
                  v_flag := 0;                     -- Set flag to 0 if invalid
                  DBMS_OUTPUT.put_line ('Flag: ' || v_flag);
                  RETURN;
               END IF;
            END IF;
         END IF;

         -- Move to the next set of revisions
         v_prev_rev_rev := v_cur_rev_rev;
         v_prev_rev_id := v_cur_rev_id;
         v_prev_eff_date := v_cur_eff_date;
         v_cur_rev_rev := v_next_rev_rev;
         v_cur_rev_id := v_next_rev_id;
         v_cur_eff_date := v_next_eff_date;

         -- Fetch the next revision
         FETCH c_revisions
          INTO v_next_eff_date, v_next_rev_rev, v_next_rev_id;

         --EXIT WHEN c_revisions%NOTFOUND;
         DBMS_OUTPUT.put_line ('-------------------------------------');
      END LOOP;

      CLOSE c_revisions;

      DBMS_OUTPUT.put_line (   'Closed cursor for revisions of item: '
                            || v_item_id
                           );
      DBMS_OUTPUT.put_line
         ('---------------------------------------------------------------------'
         );
      DBMS_OUTPUT.put_line
         ('----------------------------- NEXT ITEM ------------------------------'
         );
      DBMS_OUTPUT.put_line
         ('---------------------------------------------------------------------'
         );
   END LOOP;

   CLOSE c_items;

   DBMS_OUTPUT.put_line ('Procedure completed.');
EXCEPTION
   WHEN OTHERS
   THEN
      DBMS_OUTPUT.put_line ('An error occurred: ' || SQLERRM);
      v_flag := 0;                -- Set an error flag if an exception occurs
END check_revision_item_date;
/

DECLARE
   p_change_notice          VARCHAR2 (100) := 'ECO15083';
   -- Example change notice
   p_old_effectivity_date   DATE      := TO_DATE ('08/01/2024', 'MM/DD/YYYY');
   -- Example old effectivity date
   p_new_effectivity_date   DATE
                  := TO_DATE ('12/01/2024 00:00:00', 'MM/DD/YYYY HH24:MI:SS');
   -- Example new effectivity date with time
   v_flag                   NUMBER;
BEGIN
   apps.check_revision_item_date
                           (p_change_notice             => p_change_notice,
                            p_old_effectivity_date      => p_old_effectivity_date,
                            p_new_effectivity_date      => p_new_effectivity_date,
                            v_flag                      => v_flag
                           );
   DBMS_OUTPUT.put_line ('Flag returned: ' || v_flag);
END;
/