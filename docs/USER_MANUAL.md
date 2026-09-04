# 📘 Omega Education Centre — User Manual

> **A step-by-step guide for using the ERP system**  
> Written for Coaching Centre Owners, Admins, Teachers, and Staff

---

## Table of Contents

1. [Getting Started](#1-getting-started)
2. [Logging In](#2-logging-in)
3. [Understanding the Dashboard](#3-understanding-the-dashboard)
4. [Managing Students](#4-managing-students)
5. [Managing Teachers](#5-managing-teachers)
6. [Marking Attendance](#6-marking-attendance)
7. [Fee Management](#7-fee-management)
8. [Teacher Salary](#8-teacher-salary)
9. [Exams & Results](#9-exams--results)
10. [Daily Class Register](#10-daily-class-register)
11. [Notices & Announcements](#11-notices--announcements)
12. [Timetable](#12-timetable)
13. [Academic Calendar](#13-academic-calendar)
14. [Batches](#14-batches)
15. [Library](#15-library)
16. [Transport](#16-transport)
17. [Analytics](#17-analytics)
18. [Backup & Restore](#18-backup--restore)
19. [Settings](#19-settings)
20. [Tips & Troubleshooting](#20-tips--troubleshooting)

---

## 1. Getting Started

### What is This App?

This is a **complete management system** for coaching centres and schools. It handles:

- Student admissions and records
- Teacher management and salary payments
- Daily attendance tracking
- Fee collection and payment receipts
- Exams, results, and report cards
- Class scheduling and timetables
- Notices and announcements
- Library book management
- Transport/route management
- Data backup and restore

### First Time Setup

When you open the app for the first time, you'll see a **5-step setup wizard**:

#### Step 1: Institute Details

| Field | What to Enter | Example |
|-------|--------------|---------|
| **Institute Name** | Your coaching centre's name | "Bright Future Academy" |
| **Address** | Full address | "123 Market Road, Patna, Bihar" |
| **Phone** | Your contact number | "+91 9876543210" |
| **Email** | Your email (optional) | "info@brightfuture.com" |

> 💡 **Tip:** This information appears on ID cards, fee receipts, and reports.

#### Step 2: Select Boards

Tap on the education boards your institute follows:

- ✅ **CBSE** — Central Board of Secondary Education
- ✅ **BSEB** — Bihar School Examination Board
- ✅ **ICSE** — Indian Certificate of Secondary Education
- Others as needed

> You can add more boards later in Settings.

#### Step 3: Select Classes

Tap on the classes your institute teaches:

- Nursery, LKG, UKG
- Classes 1 through 12
- Foundation, Dropper

> Selected classes appear when adding students and creating batches.

#### Step 4: Create Admin Password

- Enter a **strong password** (minimum 8 characters)
- Confirm the password
- Click **Next**

> ⚠️ **Important:** Remember this password! You'll need it to login.

#### Step 5: Cloud Sync (Optional)

This step is **completely optional**. You can:

- **Leave it blank** → App works fully offline (no internet needed)
- **Enter Supabase credentials** → App syncs data across devices

> 💡 **Recommendation:** Start offline. You can enable cloud sync later in Settings.

Click **"Get Started"** to finish setup and go to the dashboard.

---

## 2. Logging In

### On Android Phone

After onboarding, the app opens directly to the dashboard. No login is needed on Android (data is stored locally on your phone).

### On Web Browser

When you open the app in a web browser:

1. Enter your **email address** (the one you entered in Step 1 of onboarding)
2. Enter your **password** (the one you created in Step 4)
3. Click **Login**

### Login Credentials Reference

| What | Where You Set It |
|------|-----------------|
| **Email/Username** | Step 1 of onboarding (Institute Email) |
| **Password** | Step 4 of onboarding (Admin Password) |

### If You Forgot Your Password

1. Go to **Supabase Dashboard** → SQL Editor
2. Run the recovery SQL (saved in `supabase/migrations/003_emergency_recovery.sql`)
3. Follow the steps to reset your password

---

## 3. Understanding the Dashboard

The dashboard is your **home screen** after login. It shows a live overview of your institute.

### Top Section: Header
- **Institute name** displayed at the top
- **Notification bell** — tap to see new notifications
- **Sync status** — shows if data is syncing to cloud
- **Logout button** — tap to logout

### Today's Overview (4 cards)

| Card | What It Shows |
|------|--------------|
| 🟦 **Active Students** | Total students currently enrolled |
| 🟩 **Active Teachers** | Total teachers currently working |
| 🟪 **Classes Today** | Number of classes conducted today |
| 🟧 **Teacher Hours Today** | Total hours worked by all teachers |

### Attendance Today

Shows today's attendance breakdown:
- **Student Present / Absent / Late / Leave** counts
- **Teacher Attendance**: How many teachers have recorded attendance

### Center Dues Summary

| Card | What It Shows |
|------|--------------|
| 🔴 **Fee Dues** | Total money students owe you (₹) |
| 🟧 **Salary Dues** | Total money you owe teachers (current month) (₹) |

### Academic Activity (3 cards)
- **Classes Today** — tap to see the Class Register
- **Recent Notices** — tap to see Notices
- **Recent Tests** — tap to see Exam Results

### Today's Conducted Classes
A list of all classes held today showing:
- Class and batch
- Subject name
- Teacher name
- Topic taught
- Duration (minutes)
- Start time

### Recent Examinations
Shows the latest 3 tests/exams created.

### Recent Notice Feed
Shows the latest 3 notices published.

### Quick Actions (18 tiles)
Tap any tile to go directly to that module:

| Tile | Goes To |
|------|---------|
| Students | Student list |
| Teachers | Teacher list |
| Attendance | Attendance screen |
| Notices | Notice board |
| Results | Test results |
| Salary | Salary dashboard |
| Class Register | Daily class log |
| Fees & Dues | Fee dashboard |
| Backup & Restore | Backup screen |
| Institute Config | Settings |
| Audit Log | Action history |
| License | License info |
| Branches | Branch management |
| Batches | Batch management |
| Academic Calendar | Calendar |
| Analytics | Analytics dashboard |
| Library | Book management |
| Transport | Route management |

---

## 4. Managing Students

### Viewing All Students

1. Tap **"Students"** on the dashboard
2. You'll see a list of all enrolled students
3. Use the **search bar** at the top to find a specific student
4. Use **Board filter** (CBSE/BSEB/ICSE/All) to filter
5. Use **Class filter** (1-12/All) to filter

### Adding a New Student (Admission)

1. Tap the **"+ New Admission"** button at the bottom
2. Fill in the form:

#### Photo (Optional)
- Tap the camera icon to take a photo or pick from gallery

#### Personal Information

| Field | Required? | What to Enter |
|-------|-----------|--------------|
| Student Name | ✅ Yes | Full name of student |
| Father's Name | ✅ Yes | Father's name |
| Mother's Name | No | Mother's name |
| Mobile Number | ✅ Yes | 10-digit parent/guardian number |
| Address | No | Home address |

#### Academic Information

| Field | Required? | What to Enter |
|-------|-----------|--------------|
| Board | ✅ Yes | CBSE, BSEB, ICSE, etc. |
| Class | ✅ Yes | Which class the student is joining |
| Roll Number | ✅ Yes | Unique roll number |

#### Fee & Payment Information

Choose a **Payment Method**:

**Option A: Installments**
1. Enter **Standard/Course Fee** (optional — the listed price before discount)
2. Enter **Final Agreed Fee** (the actual amount the student will pay)
3. Add installment rows:
   - Enter **amount** for each installment
   - Select **due date** for each
   - Add a **label** (e.g., "Admission", "2nd Installment")
4. The app validates that installments add up to the total

**Option B: Monthly**
1. Enter **Monthly Fee Amount** (₹)
2. Enter **Payment Due Day** (1-28)
3. Select **Start Month**
4. Enter **Duration** (number of months)
5. The app shows a preview of all monthly payments

#### Admission Payment (Optional)
- Toggle **"Record payment received now"** if the student is paying at admission
- Enter **Amount Received**, **Payment Mode** (Cash/UPI/Bank Transfer/Cheque)
- Add **remarks** if needed

3. Tap **"Complete Admission"** to save

### Viewing Student Details

1. Tap on any student card in the list
2. You'll see their complete profile with tabs for:
   - **Personal info** — name, photo, contact, address
   - **Academic info** — board, class, roll number
   - **Attendance** — month-wise attendance with percentage
   - **Fee status** — total fees, paid amount, due amount
   - **Results** — all exam results

### Editing a Student

1. Open the student's details
2. Tap the **Edit** (pencil) icon
3. Make changes
4. Tap **Save**

### Generating an ID Card

1. Open the student's details
2. Tap **"Generate ID Card"**
3. The ID card shows: Student photo, name, class, roll number, institute name
4. Tap **"Share"** or **"Download PDF"**

### Generating a Transfer Certificate (TC)

1. Open the student's details
2. Tap **"Generate TC"**
3. The TC includes: Student details, duration of study, conduct, result
4. Tap **"Share"** or **"Download PDF"**

### Importing Students from CSV

1. Go to **Students** screen
2. Tap the **upload icon** (↑) in the top-right
3. Select your CSV/Excel file
4. Map the columns to student fields
5. Review and confirm the import
6. The app shows how many students were imported successfully

### Deactivating a Student

1. Open the student's details
2. Toggle **"Active Status"** to OFF
3. The student is removed from active lists but data is preserved

---

## 5. Managing Teachers

### Viewing All Teachers

1. Tap **"Teachers"** on the dashboard
2. You'll see a list of all teachers
3. Use **search** to find by name or subject
4. Use **Subject filter** to filter by subject
5. Use **Status filter** (Active/Inactive/All)

### Adding a New Teacher

1. Tap the **"+ Add Teacher"** button
2. Fill in the form:

#### Photo (Optional)
- Tap camera icon to take or pick a photo

#### Teacher Details

| Field | Required? | What to Enter |
|-------|-----------|--------------|
| Teacher Name | ✅ Yes | Full name |
| Mobile Number | ✅ Yes | 10-digit number |
| Assigned Subjects | ✅ Yes | Tap subjects they teach (can select multiple) |
| Qualification | No | e.g., "M.Sc. Physics, B.Ed" |
| Pay Per Hour | ✅ Yes | Hourly rate in ₹ (default: ₹300) |
| Joining Date | ✅ Yes | When they joined |
| Active Status | ✅ Yes | Toggle ON/OFF |

#### Adding Custom Subjects
- Type a subject name in the text field below the subject chips
- Tap the **+** button to add it
- The new subject is automatically selected

3. Tap **"Save Teacher"**

### Viewing Teacher Details

1. Tap on any teacher card
2. You'll see:
   - Personal details and photo
   - Subjects taught
   - Attendance history (days worked, hours)
   - Salary history (payments made, pending)

### Editing a Teacher

1. Open teacher details
2. Tap **Edit**
3. Make changes
4. Tap **Save**

### Deactivating a Teacher

1. Open teacher details
2. Toggle **"Active Status"** to OFF
3. The teacher is removed from active lists

---

## 6. Marking Attendance

### Student Attendance

1. Tap **"Attendance"** on the dashboard
2. You're on the **Student Attendance** tab
3. Select the **date** (defaults to today)
4. Select the **class/batch** to view students
5. For each student, tap one of:
   - 🟢 **Present** — student attended
   - 🔴 **Absent** — student was absent
   - 🟠 **Late** — student came late
   - ⚪ **Leave** — student took leave
6. Use **"Mark All Present"** or **"Mark All Absent"** for quick marking
7. Tap **"Save Attendance"** when done

> ⚠️ You **cannot** mark attendance for future dates.

### Teacher Attendance

1. Tap the **"Teacher Attendance"** tab
2. Select the **date**
3. For each teacher:
   - Mark their **status** (Present/Absent/Late/Leave)
   - Enter **hours worked** (if Present)
4. Tap **"Save"**

> 💡 Hours worked is used for salary calculation: `Hours × Pay Per Hour = Salary`

### Viewing Attendance History

**Student History:**
1. Open a student's details
2. Tap the **Attendance** tab
3. See month-wise attendance with percentage

**Teacher History:**
1. Open a teacher's details
2. See attendance summary with total hours

---

## 7. Fee Management

### Fee Dashboard (Admin Overview)

1. Tap **"Fees & Dues"** on the dashboard
2. See overview of:
   - Total fees collected this month
   - Total outstanding fees
   - Recent payments

### Viewing a Student's Fee Status

1. Go to **Students** → Tap a student
2. Tap the **Fee** tab
3. You'll see:
   - **Total Fee**: Full course fee
   - **Paid**: Amount already paid
   - **Due**: Remaining amount
   - **Installment schedule**: Each installment with due date and status

### Recording a Fee Payment

1. Open the student's fee details
2. Tap **"Record Payment"**
3. Enter:
   - **Amount** being paid
   - **Payment Mode**: Cash, UPI, Bank Transfer, or Cheque
   - **Remarks** (optional)
4. Tap **"Save"**
5. A **fee receipt** is automatically generated

### Generating a Fee Receipt

1. After recording a payment, tap **"View Receipt"**
2. The receipt shows:
   - Student name, class, admission number
   - Payment details (amount, mode, date)
   - Institute name, logo, address
3. Tap **"Share"** to send via WhatsApp/email
4. Tap **"Download PDF"** to save

### Setting Up Fee Plans

Fee plans are set during student admission (see Section 4). You can also edit them later:

1. Open the student's fee details
2. Tap **"Edit Fee Plan"**
3. Modify the installment schedule
4. Save changes

---

## 8. Teacher Salary

### Salary Dashboard

1. Tap **"Salary"** on the dashboard
2. See overview of:
   - Total salary paid this month
   - Total pending salary
   - Teacher-wise breakdown

### How Salary is Calculated

```
Salary = Hours Worked × Pay Per Hour
```

Example:
- Teacher works 4 hours a day
- Pay rate is ₹300/hour
- Daily salary = 4 × ₹300 = ₹1,200

### Recording a Salary Payment

1. Go to **Salary Dashboard**
2. Select a teacher
3. Tap **"Record Payment"**
4. Enter:
   - **Amount** being paid
   - **Payment Mode**: Cash, UPI, Bank Transfer
   - **Date** of payment
5. Tap **"Save"**

### Viewing Salary History

1. Go to **Salary Dashboard** → Select a teacher
2. See all past payments with dates and amounts
3. See running balance (Earned - Paid = Pending)

---

## 9. Exams & Results

### Creating a Test/Exam

1. Tap **"Results"** on the dashboard
2. Tap **"+ Create Test"**
3. Fill in:
   - **Test Name**: e.g., "Unit Test 1" or "Mid-Term Exam"
   - **Test Type**: Unit Test, Mid-term, Final, Weekly
   - **Class**: Which class this test is for
   - **Date**: When the test was held
4. Add **subjects** with maximum marks
5. Tap **"Save"**

### Entering Marks

1. Go to **Results** → Select the test
2. Tap **"Enter Results"**
3. You'll see a list of students
4. For each student, enter marks for each subject
5. The app auto-calculates:
   - **Total marks**
   - **Percentage**
   - **Grade**: A+ (90+), A (75+), B (60+), C (45+), D (35+), F (<35)
6. Tap **"Save Results"**

### Viewing Results

1. Go to **Results** → Select the test
2. See class results sorted by rank
3. See:
   - **Top performers** list
   - **Pass/Fail ratio**
   - **Subject-wise** average marks

### Viewing a Student's Result History

1. Go to **Students** → Select a student
2. Tap the **Results** tab
3. See all tests they've appeared in
4. See performance trend over time

### Exporting Results

1. Open the test results
2. Tap **"Export"**
3. Choose format:
   - **PDF** — formatted report card with institute branding
   - **Excel** — raw data for further analysis
   - **Word (DOCX)** — for printing
4. Share or download the file

---

## 10. Daily Class Register

### Logging a Class

1. Tap **"Class Register"** on the dashboard
2. Tap **"+ Add Class"**
3. Fill in:
   - **Date** (defaults to today)
   - **Class & Batch** — which class was taught
   - **Subject** — what subject
   - **Topic** — specific topic covered (e.g., "Quadratic Equations")
   - **Teacher** — who taught
   - **Duration** — how long (in minutes)
   - **Start time** — when it started
   - **Notes** — optional notes
4. Tap **"Save"**

### Viewing Today's Classes

1. Go to **Class Register**
2. See all classes logged for today
3. See teacher name, subject, topic, duration

### Viewing Past Classes

1. Use the **date picker** to select a different date
2. See all classes logged for that date

---

## 11. Notices & Announcements

### Creating a Notice

1. Tap **"Notices"** on the dashboard
2. Tap **"+ Create Notice"**
3. Fill in:
   - **Title** — notice headline (e.g., "Holiday on 15th August")
   - **Content** — full notice text
   - **Priority**: Normal, Important, Urgent
   - **Target Audience**: All, Students, Teachers, Parents
   - **Publish Date** — when it goes live
   - **Expiry Date** — when it expires (optional)
4. Tap **"Publish"**

### Viewing Notices

1. Go to **Notices**
2. See all notices sorted by priority (Urgent first)
3. Red indicators = Urgent notices
4. Orange indicators = Important notices
5. Tap any notice to read full details

### Editing/Deleting a Notice

1. Open the notice
2. Tap **Edit** to modify
3. Tap **Delete** to remove
4. Tap **Archive** to hide from active list

---

## 12. Timetable

### Creating Timetable Entries

1. Go to **Timetable** from Quick Actions
2. Tap **"+ Add Entry"**
3. Fill in:
   - **Day**: Monday, Tuesday, etc.
   - **Start Time** and **End Time**
   - **Subject** — what's being taught
   - **Teacher** — who's teaching
   - **Class/Batch** — which class
4. Tap **"Save"**

### Viewing the Timetable

1. Go to **Timetable**
2. See the weekly schedule in a grid view
3. Use the **day filter** to see a specific day
4. Use the **class filter** to see a specific class's schedule

---

## 13. Academic Calendar

### Viewing the Calendar

1. Go to **Academic Calendar** from Quick Actions
2. See a monthly calendar grid
3. Navigate months using **<** and **>** arrows

### Adding a Holiday

1. Tap the **"+"** button
2. Select **"Add Holiday"**
3. Pick the date
4. Enter a reason (e.g., "Independence Day")
5. A **red dot** appears on that date

### Adding an Event

1. Tap the **"+"** button
2. Select **"Add Event"**
3. Pick the date and event type:
   - **Exam** (orange marker)
   - **Event** (blue marker)
   - **Workshop** (green marker)
4. Enter event details
5. The marker appears on the calendar

### Viewing Event Details

1. Tap any day with markers
2. A bottom sheet shows all holidays/events for that day

---

## 14. Batches

### Creating a Batch

1. Go to **Batches** from Quick Actions
2. Tap **"+ Create Batch"**
3. Fill in:
   - **Batch Name** — e.g., "Class 10 - Morning"
   - **Class** — which class
   - **Subject** — primary subject
   - **Timing** — start and end time
4. Tap **"Save"**

### Adding Students to a Batch

1. Tap on the batch card
2. You'll see a list of students with checkboxes
3. **Check** students to add them to the batch
4. **Uncheck** students to remove them
5. The student count on the batch card updates automatically

### Editing a Batch

1. Tap on the batch card
2. Tap **"Edit"**
3. Change timing, subject, or name
4. Save changes

### Filtering Batches

- Use the **class filter** to see batches for a specific class

---

## 15. Library

### Adding a Book

1. Go to **Library** from Quick Actions
2. Tap **"+ Add Book"**
3. Fill in:
   - **Title** — book name
   - **Author** — writer's name
   - **ISBN** — book's ISBN number
   - **Category** — Textbook, Reference, Fiction, etc.
   - **Quantity** — number of copies
4. Tap **"Save"**

### Issuing a Book

1. Go to **Library**
2. Tap **"Issue Book"**
3. Select the **book** from the list
4. Select the **student** or **teacher**
5. Set the **due date**
6. Tap **"Confirm"**

### Returning a Book

1. Go to **Library**
2. Tap **"Return Book"**
3. Select the issued book record
4. Tap **"Confirm Return"**

### Viewing Issue History

1. Go to **Library** → **Issue History**
2. See all past and current issues
3. See which books are overdue

---

## 16. Transport

### Adding a Route

1. Go to **Transport** from Quick Actions
2. Tap **"+ Add Route"**
3. Fill in:
   - **Route Name** — e.g., "Route A - Patna City"
   - **Pickup Points** — list of stops
   - **Timing** — pickup/drop times
4. Save the route

### Adding a Vehicle

1. Go to **Transport** → **Vehicles**
2. Tap **"+ Add Vehicle"**
3. Enter:
   - **Registration Number**
   - **Type** — Bus, Van, Auto
   - **Capacity** — max passengers
   - **Driver Name** and **Phone**
4. Save the vehicle

### Assigning Students to Routes

1. Go to **Transport**
2. Select a route
3. Tap **"Assign Students"**
4. Check students to assign
5. Set their **pickup/drop point**

---

## 17. Analytics

### Viewing Analytics

1. Go to **Analytics** from Quick Actions
2. See visual charts and graphs:
   - **Student enrollment** trends
   - **Attendance patterns** (daily/weekly/monthly)
   - **Fee collection** trends
   - **Teacher utilization** (hours worked)
   - **Exam performance** averages

### Understanding the Charts

- **Bar charts** → attendance counts
- **Line graphs** → trends over time
- **Pie charts** → demographics (gender, class distribution)

---

## 18. Backup & Restore

### Creating a Backup

1. Go to **Backup & Restore** from Quick Actions
2. Tap **"Create Backup"**
3. The app creates a complete backup of all data
4. The backup file is saved to your device
5. **Share** the backup file (via email, Google Drive, etc.)

> 💡 **Tip:** Create backups regularly — at least once a week!

### Restoring from a Backup

1. Go to **Backup & Restore**
2. Tap **"Restore from Backup"**
3. Select the backup file
4. Enter your **Organisation ID** and **Recovery Code**
5. Confirm the restore
6. All data is restored to the state when the backup was created

### Automatic Backups

The app can automatically create backups on startup:
1. Go to **Settings** → **Backup**
2. Toggle **"Auto-backup on startup"** ON

---

## 19. Settings

### Institute Profile

1. Go to **Settings** → **Institute Profile**
2. Edit:
   - Institute name, address, phone, email
   - Principal/Director name
   - Academic year
   - Logo path (for reports and ID cards)

### Display Settings

1. Go to **Settings** → **Display**
2. Change:
   - **Language**: English / Hindi (हिन्दी)
   - **Theme**: Light mode / Dark mode
   - **Date format**: DD/MM/YYYY, MM/DD/YYYY, YYYY-MM-DD

### Security Settings

1. Go to **Settings** → **Security**
2. Change:
   - **Password**: Enter old password, then new password
   - **Auto-logout timeout**: 15 min, 30 min, 1 hour, 2 hours
   - **Biometric login**: Toggle fingerprint/face ID on/off

### Notification Preferences

1. Go to **Settings** → **Notifications**
2. Toggle:
   - Push notifications ON/OFF
   - In-app notifications ON/OFF
   - Fee reminders ON/OFF
   - Attendance alerts ON/OFF

### Master Data Management

1. Go to **Settings** → **Master Data**
2. Manage:
   - **Boards**: Add/remove education boards
   - **Classes**: Add/remove classes
   - **Subjects**: Add/remove subjects
   - **Payment modes**: Add/remove options

---

## 20. Tips & Troubleshooting

### General Tips

| Tip | Description |
|-----|-------------|
| 💾 **Backup regularly** | Create a backup at least once a week |
| 📱 **Keep the app updated** | Update to the latest version for new features |
| 🔄 **Pull to refresh** | Swipe down on any list to reload data |
| 🔍 **Use search** | Type in the search bar to find anything quickly |
| 📊 **Check dashboard daily** | Start your day by reviewing the dashboard overview |

### Common Issues

#### "App shows white screen"
- Close and reopen the app
- If on web, hard refresh (Ctrl+Shift+R)
- Check your internet connection (if using Supabase)

#### "Cannot login"
- Make sure you're using the correct email and password
- Check that email confirmation is disabled in Supabase
- Try the backup admin account

#### "Data not syncing"
- Check internet connection
- Go to Settings → check Supabase URL and Key
- Try pulling down to refresh

#### "Fee installment total doesn't match"
- Make sure all installment amounts add up to the total fee
- The app shows the difference in red — adjust amounts until green

#### "Cannot mark attendance for future dates"
- This is by design — you can only mark attendance for today or past dates

#### "Teacher salary seems wrong"
- Check the teacher's **Pay Per Hour** rate
- Check the **hours worked** in teacher attendance
- Salary = Hours × Rate

### Keyboard Shortcuts (Web)

| Shortcut | Action |
|----------|--------|
| `Ctrl + Shift + R` | Hard refresh |
| `F12` | Open browser console (for debugging) |
| `Tab` | Move to next field |
| `Enter` | Submit form / Confirm action |

### Getting Help

If you encounter any issues:

1. Check this manual first
2. Look at the **Audit Log** to see what changed
3. Try **restoring from a backup** if data is corrupted
4. Contact your system administrator

---

## Quick Reference Card

### Login Credentials
| What | Value |
|------|-------|
| **Email** | Your institute email (from onboarding Step 1) |
| **Password** | Your admin password (from onboarding Step 4) |

### Key Screens

| Screen | How to Get There |
|--------|-----------------|
| Dashboard | Home screen after login |
| Students | Dashboard → Students tile |
| Teachers | Dashboard → Teachers tile |
| Attendance | Dashboard → Attendance tile |
| Fees | Dashboard → Fees & Dues tile |
| Salary | Dashboard → Salary tile |
| Results | Dashboard → Results tile |
| Notices | Dashboard → Notices tile |
| Settings | Dashboard → Institute Config tile |
| Backup | Dashboard → Backup & Restore tile |

### Daily Workflow

| Time | Action |
|------|--------|
| **Morning** | Check dashboard overview, mark teacher attendance |
| **During classes** | Log classes in Class Register |
| **After classes** | Mark student attendance |
| **When collecting fees** | Record payment, generate receipt |
| **Weekly** | Create backup, review analytics |
| **Monthly** | Pay teacher salaries, review fee dues |

---

*Last updated: September 2026*  
*Omega Education Centre ERP — User Manual v1.0.0*
