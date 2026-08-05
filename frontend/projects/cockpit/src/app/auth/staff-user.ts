export interface StaffUser {
  id: number;
  email: string;
  role: 'ward_nurse' | 'nurse' | 'physician' | 'site_admin' | 'sysadmin' | 'analyst';
  language: string;
  site_ref: number;
}
