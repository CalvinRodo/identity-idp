import { t } from '@18f/identity-i18n';
import { Alert } from '@18f/identity-components';
import { getConfigValue } from '@18f/identity-config';

function InPersonUspsOutageAlert() {
  return (
    <Alert type="warning" className="margin-bottom-4">
      <>
        <strong>{t('idv.failure.exceptions.usps_outage_error_message.post_cta.title')}</strong>
        <br />
        <br />
        {t('idv.failure.exceptions.usps_outage_error_message.post_cta.body', {
          app_name: getConfigValue('appName'),
        })}
        <br />
      </>
    </Alert>
  );
}

export default InPersonUspsOutageAlert;
