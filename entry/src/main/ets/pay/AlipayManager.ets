/**
 * @author liuzheng
 * @mail bryant_liu24@126.com
 */
import { common, Want } from '@kit.AbilityKit';
import { VipOrderData } from './VipProduct';

export class AlipayLaunchResult {
  launched: boolean;
  message: string;

  constructor(launched: boolean, message: string) {
    this.launched = launched;
    this.message = message;
  }
}

export class AlipayManager {
  static async pay(context: common.UIAbilityContext, orderData: VipOrderData): Promise<AlipayLaunchResult> {
    const directUrl = AlipayManager.resolveDirectUrl(orderData);
    if (directUrl.length > 0) {
      await AlipayManager.openUri(context, directUrl);
      return new AlipayLaunchResult(true, '请在支付宝完成支付');
    }

    const orderString = AlipayManager.resolveOrderString(orderData);
    if (orderString.length === 0) {
      return new AlipayLaunchResult(false, '支付宝参数错误');
    }

    const orderUri = `alipays://platformapi/startApp?appId=20000067&orderSuffix=${encodeURIComponent(orderString)}`;
    await AlipayManager.openUri(context, orderUri);
    return new AlipayLaunchResult(true, '请在支付宝完成支付，返回后将自动确认结果');
  }

  private static resolveOrderString(orderData: VipOrderData): string {
    return orderData.aliPayOrderString && orderData.aliPayOrderString.length > 0
      ? orderData.aliPayOrderString
      : (orderData.orderString && orderData.orderString.length > 0
        ? orderData.orderString
        : (orderData.alipayOrderString ?? ''));
  }

  private static resolveDirectUrl(orderData: VipOrderData): string {
    return orderData.payUrl && orderData.payUrl.length > 0
      ? orderData.payUrl
      : (orderData.paymentUrl && orderData.paymentUrl.length > 0
        ? orderData.paymentUrl
        : (orderData.cashierUrl && orderData.cashierUrl.length > 0
          ? orderData.cashierUrl
          : (orderData.h5Url ?? '')));
  }

  private static async openUri(context: common.UIAbilityContext, uri: string): Promise<void> {
    const want: Want = {
      action: 'ohos.want.action.viewData',
      uri: uri
    };
    await context.startAbility(want);
  }
}
