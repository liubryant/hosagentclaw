/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { AppPreferences } from '../storage/AppPreferences';

const FREE_VIDEO_DAILY = 1;
const FREE_IMAGE_DAILY = 10;
const VIP_VIDEO_DAILY = 5;
const VIP_IMAGE_DAILY = 50;

function today(): string {
  const date = new Date();
  const month = `${date.getMonth() + 1}`.padStart(2, '0');
  const day = `${date.getDate()}`.padStart(2, '0');
  return `${date.getFullYear()}${month}${day}`;
}

export class QuotaManager {
  static freeVideoLimit(): number {
    const value = AppPreferences.shared.serverFreeVideoDaily;
    return value >= 0 ? value : FREE_VIDEO_DAILY;
  }

  static freeImageLimit(): number {
    const value = AppPreferences.shared.serverFreeImageDaily;
    return value >= 0 ? value : FREE_IMAGE_DAILY;
  }

  static vipVideoLimit(): number {
    const value = AppPreferences.shared.serverVipVideoDaily;
    return value >= 0 ? value : VIP_VIDEO_DAILY;
  }

  static vipImageLimit(): number {
    const value = AppPreferences.shared.serverVipImageDaily;
    return value >= 0 ? value : VIP_IMAGE_DAILY;
  }

  static todayVideoCount(): number {
    return AppPreferences.shared.quotaVideoDate === today() ? AppPreferences.shared.quotaVideoCount : 0;
  }

  static todayImageCount(): number {
    return AppPreferences.shared.quotaImageDate === today() ? AppPreferences.shared.quotaImageCount : 0;
  }

  static consumeVideo(): void {
    const currentDay = today();
    const count = AppPreferences.shared.quotaVideoDate === currentDay ? AppPreferences.shared.quotaVideoCount : 0;
    AppPreferences.shared.quotaVideoDate = currentDay;
    AppPreferences.shared.quotaVideoCount = count + 1;
  }

  static consumeImage(): void {
    const currentDay = today();
    const count = AppPreferences.shared.quotaImageDate === currentDay ? AppPreferences.shared.quotaImageCount : 0;
    AppPreferences.shared.quotaImageDate = currentDay;
    AppPreferences.shared.quotaImageCount = count + 1;
  }
}
