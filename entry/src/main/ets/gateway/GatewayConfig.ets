/**
 * 对应 iOS GatewayConfig.swift。
 */
export class GatewayConfig {
  baseURL: string;
  token: string | null;
  allowInsecureLocalNetwork: boolean;

  constructor(baseURL: string, token: string | null, allowInsecureLocalNetwork: boolean) {
    this.baseURL = baseURL;
    this.token = token;
    this.allowInsecureLocalNetwork = allowInsecureLocalNetwork;
  }
}
