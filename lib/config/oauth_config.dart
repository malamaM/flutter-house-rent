/// Public OAuth client identifiers used by Haven's native sign-in flows.
///
/// OAuth client IDs are app identifiers, not secrets. Never add an OAuth
/// client secret to the Flutter application.
abstract final class OAuthConfig {
  static const googleWebClientId =
      '91306448097-p94qtvjqn0ba53drj556ga3m28l4o12c.apps.googleusercontent.com';

  static const googleIosClientId =
      '91306448097-dl42f87d4f2gdg1ap7fn5uqhfe0nua6n.apps.googleusercontent.com';
}
