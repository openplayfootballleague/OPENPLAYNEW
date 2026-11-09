export function ageOnUkDate(dateOfBirth: string, instant: Date = new Date()): number | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateOfBirth);
  if (!match || Number.isNaN(instant.getTime())) return null;

  const birthYear = Number(match[1]);
  const birthMonth = Number(match[2]);
  const birthDay = Number(match[3]);
  const validatedBirthDate = new Date(Date.UTC(birthYear, birthMonth - 1, birthDay));
  if (
    birthYear < 1900 ||
    validatedBirthDate.getUTCFullYear() !== birthYear ||
    validatedBirthDate.getUTCMonth() + 1 !== birthMonth ||
    validatedBirthDate.getUTCDate() !== birthDay
  ) return null;

  const todayParts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Europe/London",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(instant);
  const part = (type: Intl.DateTimeFormatPartTypes) =>
    Number(todayParts.find((item) => item.type === type)?.value);
  const todayYear = part("year");
  const todayMonth = part("month");
  const todayDay = part("day");

  let age = todayYear - birthYear;
  if (todayMonth < birthMonth || (todayMonth === birthMonth && todayDay < birthDay)) age -= 1;
  return age;
}
