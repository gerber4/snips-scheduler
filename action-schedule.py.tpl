#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from typing import Dict
import configparser
from hermes_python.hermes import Hermes, IntentMessage
from hermes_python.ffi.utils import MqttOptions
from hermes_python.ontology import *
import io
import db

CONFIGURATION_ENCODING_FORMAT = "utf-8"
CONFIG_INI = "config.ini"


class SnipsConfigParser(configparser.SafeConfigParser):
    def to_dict(self):
        return {section: {option_name: option for option_name, option in self.items(section)} for section in self.sections()}


def read_configuration_file(configuration_file):
    try:
        with io.open(configuration_file, encoding=CONFIGURATION_ENCODING_FORMAT) as f:
            conf_parser = SnipsConfigParser()
            conf_parser.readfp(f)
            return conf_parser.to_dict()
    except (IOError, configparser.Error) as e:
        return dict()


def subscribe_intent_callback(hermes, intent_message):
    # type: (Hermes, IntentMessage) -> None
    conf = read_configuration_file(CONFIG_INI)
    action_wrapper(hermes, intent_message, conf)


def action_wrapper(hermes, intent_message, conf):
    # type: (Hermes, IntentMessage, Dict) -> None

    handle = db.Database()

    if len(intent_message.slots) == 1:
        time = intent_message.slots["time"].first().value

        handle.create_event(time)
        hermes.publish_end_session(intent_message.session_id, "I'll remind you!")
        return

    if len(intent_message.slots) == 2:
        time = intent_message.slots["time"].first().value
        event = intent_message.slots["event"].first().value

        handle.create_event(time, event)
        hermes.publish_end_session(intent_message.session_id, "I'll remind you to {}".format(event))
        return


if __name__ == "__main__":
    mqtt_opts = MqttOptions()
    with Hermes(mqtt_options=mqtt_opts) as h:
        h.subscribe_intent("JosephBGerber:SetReminder", subscribe_intent_callback).start()
