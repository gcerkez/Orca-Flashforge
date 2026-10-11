#include "ComCommand.hpp"
#include "slic3r/Utils/Http.hpp"
#include <boost/log/trivial.hpp>
#include <nlohmann/json.hpp>

namespace Slic3r { namespace GUI {

int ComCommand::s_commandNum = ComInvalidCommandId + 1;

ComErrno ComCameraStreamCtrl::sendLanCameraStreamCtrl(const com_command_exec_data_t &data,
                                                      const std::string &action)
{
    nlohmann::json body;
    body["serialNumber"]    = data.serialNumber;
    body["checkCode"]       = data.checkCode;
    body["payload"]["cmd"]  = "streamCtrl_cmd";
    body["payload"]["args"] = {{"action", action}};

    std::string url = std::string("http://") + data.ip + ":" + std::to_string(data.port) + "/control";

    ComErrno result = COM_ERROR;
    BOOST_LOG_TRIVIAL(info) << "sendLanCameraStreamCtrl: streamCtrl_cmd action=" << action;

    Http::post(url)
        .header("Content-Type", "application/json")
        .timeout_connect(ComTimeoutLanA / 1000)
        .timeout_max(ComTimeoutLanA / 1000)
        .set_post_body(body.dump())
        .on_complete([&result](std::string reply, unsigned status) {
            if (status < 200 || status >= 300) {
                BOOST_LOG_TRIVIAL(warning) << "sendLanCameraStreamCtrl: http status " << status;
                return;
            }
            try {
                nlohmann::json json = nlohmann::json::parse(reply);
                if (json.contains("code") && json["code"].is_number_integer() &&
                    json["code"].get<int>() != 0) {
                    BOOST_LOG_TRIVIAL(warning) << "sendLanCameraStreamCtrl: printer returned code "
                                               << json["code"].get<int>();
                    return;
                }
            } catch (const std::exception &) {
                BOOST_LOG_TRIVIAL(debug) << "sendLanCameraStreamCtrl: reply was not json";
            }
            result = COM_OK;
        })
        .on_error([](std::string, std::string error, unsigned status) {
            BOOST_LOG_TRIVIAL(warning) << "sendLanCameraStreamCtrl failed, status " << status
                                       << ", " << error;
        })
        .perform_sync();

    return result;
}

}} // namespace Slic3r::GUI

